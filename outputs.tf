output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.cluster_endpoint
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = var.enable_argocd ? "https://argocd.${var.domain_name}" : null
}

output "load_balancer_controller_enabled" {
  description = "Whether AWS Load Balancer Controller is enabled"
  value       = var.enable_aws_load_balancer_controller
}

output "external_dns_enabled" {
  description = "Whether External DNS is enabled"
  value       = var.enable_external_dns
}

output "external_secrets_enabled" {
  description = "Whether External Secrets is enabled"
  value       = var.enable_external_secrets
}

output "aws_load_balancer_controller_service_account" {
  description = "Service account used by AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? "aws-load-balancer-controller" : null
}

output "external_dns_service_account" {
  description = "Service account used by External DNS"
  value       = var.enable_external_dns ? "external-dns" : null
}

output "external_secrets_service_account" {
  description = "Service account used by External Secrets"
  value       = var.enable_external_secrets ? "external-secrets" : null
}

output "argocd_service_account" {
  description = "Service account used by ArgoCD"
  value       = var.enable_argocd ? "argocd-application-controller" : null
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore if created"
  value       = var.create_cluster_secret_store && var.enable_external_secrets ? "aws-secretsmanager" : null
}