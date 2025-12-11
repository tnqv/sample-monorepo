# ===========================================
# Shared Infrastructure
# ===========================================
# Resources shared across all services.
# Managed by infrastructure team.

# ===========================================
# SQS Queue for Tasks
# ===========================================

locals {
  ses_sender_email           = "noreply@${var.ses_domain}"
  ses_configuration_set_name = "${var.project_name}-${var.environment}-ses-config"
}

module "tasks_queue" {
  source = "./modules/sqs-queue"

  name         = "tasks"
  project_name = var.project_name
  environment  = var.environment

  visibility_timeout_seconds = 300     # 5 minutes
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 20      # Long polling

  enable_dlq        = true
  max_receive_count = 3 # Max 3 attempts before moving to DLQ

  publisher_role_names = [aws_iam_role.ecs_task_role.name]
  consumer_role_names  = [aws_iam_role.ecs_task_role.name]

  tags = {
    Component = "messaging"
  }
}

# ===========================================
# Secrets Manager (for services that need secrets)
# ===========================================

resource "aws_secretsmanager_secret" "worker_secret" {
  name        = "${var.project_name}/${var.environment}/worker-secret"
  description = "Secret key for sampleworker service"

  tags = {
    Name        = "${var.project_name}-${var.environment}-worker-secret"
    Environment = var.environment
    Component   = "secrets"
  }
}

resource "aws_secretsmanager_secret_version" "worker_secret" {
  secret_id = aws_secretsmanager_secret.worker_secret.id
  secret_string = jsonencode({
    SECRET_KEY = var.worker_secret_key
  })
}

# ===========================================
# SES (Simple Email Service) Configuration
# ===========================================

# SES Email Identity (domain or email address)
resource "aws_ses_email_identity" "sender" {
  email = local.ses_sender_email
}


# IAM Policy for allowing ECS Task Role to send emails via SES
resource "aws_iam_role_policy" "ses_send_email" {
  name = "${var.project_name}-${var.environment}-ses-send-email"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = aws_ses_email_identity.sender.arn
      }
    ]
  })
}
