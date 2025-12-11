# ===========================================
# Infrastructure Variables
# ===========================================
# These are infrastructure-wide settings shared across all services.
# Service-specific configuration is in each service-*.tf file.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "email-platform"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# ===========================================
# LocalStack Configuration
# ===========================================

variable "use_localstack" {
  description = "Whether to use LocalStack"
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

# ===========================================
# Secrets
# ===========================================

variable "worker_secret_key" {
  description = "Secret key for worker (will be stored in Secrets Manager)"
  type        = string
  default     = "change-me-in-production"
  sensitive   = true
}

# ===========================================
# SES Configuration
# ===========================================

variable "ses_domain" {
  description = "Domain to use as sender for SES"
  type        = string
  default     = "example.com"
}
