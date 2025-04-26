variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# Required EKS cluster variables - must be provided by user
variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the existing EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the existing EKS cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster is deployed"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC Provider associated with the EKS cluster"
  type        = string
}

# AWS Load Balancer Controller variables
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

# External DNS variables
variable "enable_external_dns" {
  description = "Enable External DNS"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for cluster services (ArgoCD will be created as argocd.domain_name)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Hosted Zone ID for Domain Name in Route53"
  type = string
  default = ""
}

# External Secrets variables
variable "enable_external_secrets" {
  description = "Enable External Secrets"
  type        = bool
  default     = true
}

# ArgoCD variables
variable "enable_argocd" {
  description = "Enable ArgoCD"
  type        = bool
  default     = true
}

variable "acm_cert_id" {
  description = "ACM certificate ID for HTTPS"
  type        = string
}

# Additional addon settings
variable "aws_load_balancer_controller_settings" {
  description = "Additional settings for AWS Load Balancer Controller (optional)"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = []
}

variable "external_dns_settings" {
  description = "Additional settings for External DNS (optional)"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = []
}

variable "external_secrets_settings" {
  description = "Additional settings for External Secrets (optional)"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = []
}

variable "argocd_settings" {
  description = "Additional settings for ArgoCD (optional)"
  type        = map(string)
  default     = {}
}

variable "create_cluster_secret_store" {
  description = "Create a default ClusterSecretStore for AWS Secrets Manager"
  type        = bool
  default     = true
}