# ===========================================
# Required Variables
# ===========================================

variable "name" {
  description = "Name of the queue"
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

# ===========================================
# Queue Configuration
# ===========================================

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for the queue (seconds)"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Message retention period (seconds). Max 14 days = 1209600"
  type        = number
  default     = 345600 # 4 days
}

variable "max_message_size" {
  description = "Maximum message size (bytes). Max 256KB = 262144"
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "Delay for messages (seconds)"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time (seconds). 0 = short polling"
  type        = number
  default     = 20 # Enable long polling
}

# ===========================================
# Dead Letter Queue Configuration
# ===========================================

variable "enable_dlq" {
  description = "Enable Dead Letter Queue"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Number of times a message can be received before being sent to DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "Message retention period for DLQ (seconds)"
  type        = number
  default     = 1209600 # 14 days
}

# ===========================================
# FIFO Queue Configuration
# ===========================================

variable "fifo_queue" {
  description = "Create a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication for FIFO queues"
  type        = bool
  default     = false
}

# ===========================================
# IAM Configuration
# ===========================================

variable "publisher_role_arns" {
  description = "IAM role ARNs that can publish to the queue (for queue policy)"
  type        = list(string)
  default     = []
}

variable "consumer_role_arns" {
  description = "IAM role ARNs that can consume from the queue (for queue policy)"
  type        = list(string)
  default     = []
}

variable "publisher_role_names" {
  description = "IAM role names to attach publisher policy (creates aws_iam_role_policy)"
  type        = list(string)
  default     = []
}

variable "consumer_role_names" {
  description = "IAM role names to attach consumer policy (creates aws_iam_role_policy)"
  type        = list(string)
  default     = []
}

# ===========================================
# Additional Options
# ===========================================

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

