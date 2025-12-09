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
# Sample API Configuration
# ===========================================

variable "sampleapi_cpu" {
  description = "CPU units for sampleapi task (1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "sampleapi_memory" {
  description = "Memory (MB) for sampleapi task"
  type        = number
  default     = 512
}

variable "sampleapi_container_port" {
  description = "Container port for sampleapi"
  type        = number
  default     = 8080
}

variable "sampleapi_desired_count" {
  description = "Desired number of sampleapi tasks"
  type        = number
  default     = 2
}

variable "sampleapi_image_tag" {
  description = "Docker image tag for sampleapi"
  type        = string
  default     = "latest"
}

# ===========================================
# Sample Worker Configuration
# ===========================================

variable "sampleworker_cpu" {
  description = "CPU units for sampleworker task (1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "sampleworker_memory" {
  description = "Memory (MB) for sampleworker task"
  type        = number
  default     = 512
}

variable "sampleworker_desired_count" {
  description = "Desired number of sampleworker tasks"
  type        = number
  default     = 1
}

variable "sampleworker_image_tag" {
  description = "Docker image tag for sampleworker"
  type        = string
  default     = "latest"
}

variable "worker_interval" {
  description = "Worker processing interval"
  type        = string
  default     = "10s"
}

variable "worker_secret_key" {
  description = "Secret key for worker (will be stored in Secrets Manager)"
  type        = string
  default     = "change-me-in-production"
  sensitive   = true
}

# ===========================================
# Common Configuration
# ===========================================

variable "log_level" {
  description = "Log level for services"
  type        = string
  default     = "info"
}

variable "image_tag" {
  description = "Docker image tag for all services (can be overridden per service in service.yaml)"
  type        = string
  default     = "latest"
}

# ===========================================
# Auto Scaling Configuration
# ===========================================

variable "enable_autoscaling" {
  description = "Enable auto scaling for ECS services"
  type        = bool
  default     = false
}

variable "sampleapi_min_count" {
  description = "Minimum number of sampleapi tasks"
  type        = number
  default     = 1
}

variable "sampleapi_max_count" {
  description = "Maximum number of sampleapi tasks"
  type        = number
  default     = 4
}

variable "sampleworker_min_count" {
  description = "Minimum number of sampleworker tasks"
  type        = number
  default     = 1
}

variable "sampleworker_max_count" {
  description = "Maximum number of sampleworker tasks"
  type        = number
  default     = 3
}

