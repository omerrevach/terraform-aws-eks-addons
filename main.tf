terraform {
  required_version = ">= 1.3.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Fixed timeouts that users cannot override
  addon_timeouts = {
    after_eks              = "20s"
    after_lb_controller    = "30s"
    after_external_dns     = "20s"
    after_external_secrets = "20s"
  }
  
  # Default AWS Load Balancer Controller settings
  default_aws_lb_controller_settings = [
    { name = "region", value = var.region },
    { name = "vpcId", value = var.vpc_id }
  ]
  
  # Merge default and user-provided settings
  aws_lb_controller_settings = concat(
    local.default_aws_lb_controller_settings,
    var.aws_load_balancer_controller_settings
  )
  
  # Default External DNS settings
  default_external_dns_settings = [
    { name = "policy", value = "sync" },
    { name = "sources[0]", value = "service" },
    { name = "sources[1]", value = "ingress" }
  ]
  
  # Add domain filter only if domain is provided
  domain_external_dns_settings = var.domain_name != "" ? [
    { name = "domainFilters[0]", value = var.domain_name },
    { name = "txtOwnerId", value = "eks-${var.cluster_name}" }
  ] : []
  
  # Combine all External DNS settings
  external_dns_settings = concat(
    local.default_external_dns_settings,
    local.domain_external_dns_settings,
    var.external_dns_settings
  )
  
  # Default External Secrets settings
  default_external_secrets_settings = [
    { name = "region", value = var.region }
  ]
  
  # Merge default and user-provided settings
  external_secrets_settings = concat(
    local.default_external_secrets_settings,
    var.external_secrets_settings
  )
}

# Create time-based resources to enforce ordering
resource "time_sleep" "after_eks" {
  create_duration = local.addon_timeouts["after_eks"]
}

module "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Only enable the AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true

  aws_load_balancer_controller = {
    set = local.aws_lb_controller_settings
  }

  depends_on = [
    time_sleep.after_eks
  ]
}

resource "time_sleep" "after_lb_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  
  depends_on = [module.aws_load_balancer_controller]
  create_duration = local.addon_timeouts["after_lb_controller"]
}

module "external_dns" {
  count = var.enable_external_dns ? 1 : 0
  
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Only enable External DNS
  enable_external_dns = true
  external_dns_route53_zone_arns = var.hosted_zone_id != "" ? ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"] : []

  external_dns = {
    set = local.external_dns_settings
  }

  depends_on = [
    time_sleep.after_lb_controller
  ]
}

resource "time_sleep" "after_external_dns" {
  count = var.enable_external_dns ? 1 : 0
  
  depends_on = [module.external_dns]
  create_duration = local.addon_timeouts["after_external_dns"]
}

module "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0
  
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Only enable External Secrets
  enable_external_secrets = true

  external_secrets = {
    set = local.external_secrets_settings
  }

  depends_on = [
    time_sleep.after_external_dns
  ]
}

resource "time_sleep" "after_external_secrets" {
  count = var.enable_external_secrets ? 1 : 0
  
  depends_on = [module.external_secrets]
  create_duration = local.addon_timeouts["after_external_secrets"]
}

resource "kubectl_manifest" "cluster_secret_store" {
  count = var.create_cluster_secret_store && var.enable_external_secrets ? 1 : 0
  
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secretsmanager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: "${var.region}"
          auth:
            jwt:
              serviceAccountRef:
                name: external-secrets
                namespace: external-secrets
  YAML
  
  depends_on = [
    time_sleep.after_external_secrets
  ]
}

module "argocd" {
  count = var.enable_argocd ? 1 : 0
  
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Only enable ArgoCD
  enable_argocd = true

  argocd = merge(
    {
      namespace     = "argocd"
      chart_version = "5.51.6"
      repository    = "https://argoproj.github.io/argo-helm"
      values = [
        <<-EOF
        server:
          extraArgs:
            - --insecure
          service:
            type: ClusterIP
            servicePortHttp: 8080
          ingress:
            enabled: true
            ingressClassName: alb
            annotations:
              alb.ingress.kubernetes.io/scheme: internet-facing
              alb.ingress.kubernetes.io/target-type: ip
              alb.ingress.kubernetes.io/group.name: addons-group
              alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
              alb.ingress.kubernetes.io/backend-protocol: HTTP
              alb.ingress.kubernetes.io/healthcheck-path: /
              alb.ingress.kubernetes.io/success-codes: "200-399"
              alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=120
              alb.ingress.kubernetes.io/ssl-redirect: '443'
              alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:${var.region}:${data.aws_caller_identity.current.account_id}:certificate/${var.acm_cert_id}
              external-dns.alpha.kubernetes.io/hostname: argocd.${var.domain_name}
            hosts:
              - argocd.${var.domain_name}
            path: /
            pathType: Prefix
          configs:
            cm:
              url: https://argocd.${var.domain_name}
            params:
              server.insecure: "true"
        EOF
      ]
    },
    var.argocd_settings
  )

  depends_on = [
    time_sleep.after_external_secrets
  ]
}