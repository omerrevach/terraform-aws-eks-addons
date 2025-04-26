# EKS Addons Module

A Terraform module to deploy essential managed add-ons for an existing Amazon EKS cluster with proper dependency management.

## Features

- Addon management for existing EKS clusters
- Core add-ons with correct dependency ordering:
  1. AWS Load Balancer Controller
  2. External DNS
  3. External Secrets
  4. ArgoCD
- Optional ClusterSecretStore for AWS Secrets Manager
- Sensible defaults with customization options

## Usage

```hcl
# First create your VPC and EKS cluster using your preferred method
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "my-eks-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  
  # Required tags for AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/my-cluster" = "shared"
  }
  
  # Required tags for Karpenter and ALB/NLB
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/my-cluster" = "shared"
    "karpenter.sh/discovery" = "my-cluster"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  
  cluster_name    = "my-cluster"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Enable IRSA for add-ons to use IAM roles
  enable_irsa = true
  
  # Karpenter node group tags
  node_security_group_tags = {
    "karpenter.sh/discovery" = "my-cluster"
  }
  
  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      
      # Karpenter discovery tags
      tags = {
        "karpenter.sh/discovery" = "my-cluster"
      }
    }
  }
}

# Then add the addons with this module
module "eks_addons" {
  source  = "example/eks-addons/aws"
  version = "1.0.0"
  
  # Required EKS cluster information
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_version                    = module.eks.cluster_version
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  vpc_id                             = module.vpc.vpc_id
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  region                             = "us-west-2"
  
  # Addon configuration (all optional with sensible defaults)
  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true
  enable_external_secrets             = true
  enable_argocd                       = true
  
  # Domain configuration
  domain_name    = "example.com"
  hosted_zone_id = "Z123456789ABCDEFGHIJK"  # Route53 Hosted Zone ID
  acm_cert_id    = "12345678-1234-1234-1234-123456789012"
  
  # ClusterSecretStore for AWS Secrets Manager
  create_cluster_secret_store = true
  
  # Additional add-on settings (optional)
  aws_load_balancer_controller_settings = [
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" }
  ]
  
  external_dns_settings = [
    { name = "interval", value = "2m" }
  ]
  
  external_secrets_settings = [
    { name = "serviceAccount.name", value = "external-secrets" }
  ]
  
  argocd_settings = {
    values = [
      <<-EOF
      server:
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
      EOF
    ]
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.2 |
| aws | ~> 5.0 |
| helm | >= 2.7.0 |
| kubectl | ~> 1.14 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| helm | >= 2.7.0 |
| kubectl | ~> 1.14 |
| time | n/a |

## Resources

| Name | Type |
|------|------|
| [module.aws_load_balancer_controller](https://registry.terraform.io/modules/aws-ia/eks-blueprints-addons/aws/latest) | module |
| [module.external_dns](https://registry.terraform.io/modules/aws-ia/eks-blueprints-addons/aws/latest) | module |
| [module.external_secrets](https://registry.terraform.io/modules/aws-ia/eks-blueprints-addons/aws/latest) | module |
| [module.argocd](https://registry.terraform.io/modules/aws-ia/eks-blueprints-addons/aws/latest) | module |
| [kubectl_manifest.cluster_secret_store](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [time_sleep.after_eks](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.after_lb_controller](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.after_external_dns](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.after_external_secrets](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the existing EKS cluster | `string` | n/a | yes |
| cluster_endpoint | Endpoint of the existing EKS cluster | `string` | n/a | yes |
| cluster_version | Kubernetes version of the existing EKS cluster | `string` | n/a | yes |
| cluster_certificate_authority_data | Base64 encoded certificate data required to communicate with the cluster | `string` | n/a | yes |
| vpc_id | ID of the VPC where the EKS cluster is deployed | `string` | n/a | yes |
| oidc_provider_arn | ARN of the OIDC Provider associated with the EKS cluster | `string` | n/a | yes |
| region | AWS region | `string` | `"us-west-2"` | no |
| enable_aws_load_balancer_controller | Enable AWS Load Balancer Controller | `bool` | `true` | no |
| enable_external_dns | Enable External DNS | `bool` | `true` | no |
| domain_name | Domain name for cluster services (ArgoCD will be created as argocd.domain_name) | `string` | n/a | yes |
| hosted_zone_id | Hosted Zone ID for Domain Name in Route53 | `string` | n/a | yes |
| enable_external_secrets | Enable External Secrets | `bool` | `true` | no |
| enable_argocd | Enable ArgoCD | `bool` | `true` | no |
| acm_cert_id | ACM certificate ID for HTTPS | `string` | n/a | yes |
| create_cluster_secret_store | Create a default ClusterSecretStore for AWS Secrets Manager | `bool` | `true` | no |
| aws_load_balancer_controller_settings | Additional settings for AWS Load Balancer Controller (optional) | `list(object({ name = string, value = string }))` | `[]` | no |
| external_dns_settings | Additional settings for External DNS (optional) | `list(object({ name = string, value = string }))` | `[]` | no |
| external_secrets_settings | Additional settings for External Secrets (optional) | `list(object({ name = string, value = string }))` | `[]` | no |
| argocd_settings | Additional settings for ArgoCD (optional) | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | EKS cluster name |
| cluster_endpoint | Endpoint for EKS control plane |
| region | AWS region |
| argocd_url | ArgoCD URL |
| load_balancer_controller_enabled | Whether AWS Load Balancer Controller is enabled |
| external_dns_enabled | Whether External DNS is enabled |
| external_secrets_enabled | Whether External Secrets is enabled |
| aws_load_balancer_controller_service_account | Service account used by AWS Load Balancer Controller |
| external_dns_service_account | Service account used by External DNS |
| external_secrets_service_account | Service account used by External Secrets |
| argocd_service_account | Service account used by ArgoCD |
| cluster_secret_store_name | Name of the ClusterSecretStore if created |

## Add-on Dependency Management

This module ensures proper ordering of add-on installation through a combination of separate module calls and time-based dependencies:

1. A small delay ensures the EKS cluster is ready (20s)
2. AWS Load Balancer Controller is installed
3. Another delay ensures the controller is running (30s)
4. External DNS is installed
5. Another delay ensures External DNS is running (20s)
6. External Secrets is installed
7. Finally, after a delay (20s), ArgoCD is installed

This approach guarantees that each component has its dependencies properly initialized before installation.

## Required Tags for AWS Services

### VPC and Subnet Tags

For the AWS Load Balancer Controller and Karpenter to work properly, your VPC needs specific tags:

1. **Public Subnet Tags** (for external load balancers):
   ```
   kubernetes.io/role/elb = 1
   kubernetes.io/cluster/<cluster-name> = shared
   ```

2. **Private Subnet Tags** (for internal load balancers and Karpenter):
   ```
   kubernetes.io/role/internal-elb = 1  
   kubernetes.io/cluster/<cluster-name> = shared
   karpenter.sh/discovery = <cluster-name>
   ```

### EKS Node Group Tags

For Karpenter to discover and manage nodes:

1. **Security Group Tags**:
   ```
   karpenter.sh/discovery = <cluster-name>
   ```

2. **Node Group Tags**:
   ```
   karpenter.sh/discovery = <cluster-name>
   ```

Make sure to replace `<cluster-name>` with your actual EKS cluster name in all tags.

## Finding Your Route53 Hosted Zone ID

To find your Route53 Hosted Zone ID:

1. Sign in to the AWS Management Console
2. Navigate to the Route53 service
3. Click on "Hosted Zones" in the left sidebar
4. Find your domain in the list
5. The "Hosted Zone ID" column shows the ID (e.g., Z123456789ABCDEFGHIJK)

This is the value you should use for the `hosted_zone_id` variable.

## Add-on Compatibility

| Add-on | Purpose | Dependencies |
|--------|---------|--------------|
| AWS Load Balancer Controller | Manages AWS ALB/NLB for Kubernetes services | EKS Cluster |
| External DNS | Synchronizes Kubernetes Ingress resources with DNS providers | AWS Load Balancer Controller |
| External Secrets | Synchronizes Kubernetes secrets with external secret stores | None, but installed after External DNS for consistency |
| ArgoCD | GitOps continuous delivery tool for Kubernetes | All other add-ons (for managing app deployments) |

## Authors

Module is maintained by [Omer Revach]

## License

Apache 2 Licensed. See LICENSE for full details.