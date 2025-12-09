# ===========================================
# Required Variables
# ===========================================

variable "name" {
  description = "Name of the service"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the service"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for the service"
  type        = list(string)
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# ===========================================
# Container Configuration
# ===========================================

variable "container_image" {
  description = "Container image URL with tag"
  type        = string
}

variable "container_port" {
  description = "Container port (set to null for worker services)"
  type        = number
  default     = null
}

variable "cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MB) for the task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

# ===========================================
# Environment & Secrets
# ===========================================

variable "environment_variables" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets from Secrets Manager or Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# ===========================================
# Health Check
# ===========================================

variable "health_check_path" {
  description = "Health check path (set to null for worker services)"
  type        = string
  default     = null
}

variable "health_check_command" {
  description = "Custom health check command for the container"
  type        = list(string)
  default     = null
}

# ===========================================
# Load Balancer (Optional)
# ===========================================

variable "enable_load_balancer" {
  description = "Enable ALB integration"
  type        = bool
  default     = false
}

variable "lb_listener_arn" {
  description = "ALB listener ARN"
  type        = string
  default     = null
}

variable "lb_listener_rule_priority" {
  description = "ALB listener rule priority"
  type        = number
  default     = 100
}

variable "lb_path_patterns" {
  description = "Path patterns for ALB routing"
  type        = list(string)
  default     = ["/*"]
}

variable "lb_health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/health"
}

# ===========================================
# Auto Scaling (Optional)
# ===========================================

variable "enable_autoscaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = false
}

variable "min_count" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of tasks"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

# ===========================================
# Additional Options
# ===========================================

variable "assign_public_ip" {
  description = "Assign public IP to tasks"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

