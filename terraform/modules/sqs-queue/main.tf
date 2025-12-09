# ===========================================
# Local Values
# ===========================================

locals {
  queue_name     = "${var.project_name}-${var.environment}-${var.name}${var.fifo_queue ? ".fifo" : ""}"
  dlq_queue_name = "${var.project_name}-${var.environment}-${var.name}-dlq${var.fifo_queue ? ".fifo" : ""}"

  common_tags = merge(var.tags, {
    Name        = local.queue_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ===========================================
# Dead Letter Queue (Optional)
# ===========================================

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name = local.dlq_queue_name

  message_retention_seconds = var.dlq_message_retention_seconds
  
  # FIFO settings
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  tags = merge(local.common_tags, {
    Name = local.dlq_queue_name
    Type = "dlq"
  })
}

# ===========================================
# Main Queue
# ===========================================

resource "aws_sqs_queue" "this" {
  name = local.queue_name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # FIFO settings
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  # Dead Letter Queue
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = merge(local.common_tags, {
    Type = "main"
  })
}

# ===========================================
# Queue Policy
# ===========================================

resource "aws_sqs_queue_policy" "this" {
  count = length(var.publisher_role_arns) > 0 || length(var.consumer_role_arns) > 0 ? 1 : 0

  queue_url = aws_sqs_queue.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Publisher permissions
      length(var.publisher_role_arns) > 0 ? [
        {
          Sid       = "AllowPublish"
          Effect    = "Allow"
          Principal = {
            AWS = var.publisher_role_arns
          }
          Action = [
            "sqs:SendMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl"
          ]
          Resource = aws_sqs_queue.this.arn
        }
      ] : [],
      # Consumer permissions
      length(var.consumer_role_arns) > 0 ? [
        {
          Sid       = "AllowConsume"
          Effect    = "Allow"
          Principal = {
            AWS = var.consumer_role_arns
          }
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl",
            "sqs:ChangeMessageVisibility"
          ]
          Resource = aws_sqs_queue.this.arn
        }
      ] : []
    )
  })
}

# ===========================================
# IAM Policy Documents (for attaching to roles)
# ===========================================

data "aws_iam_policy_document" "publisher" {
  statement {
    sid    = "SQSPublish"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.this.arn]
  }
}

data "aws_iam_policy_document" "consumer" {
  statement {
    sid    = "SQSConsume"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [aws_sqs_queue.this.arn]
  }

  # Allow access to DLQ for monitoring
  dynamic "statement" {
    for_each = var.enable_dlq ? [1] : []
    content {
      sid    = "SQSDLQRead"
      effect = "Allow"
      actions = [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage"
      ]
      resources = [aws_sqs_queue.dlq[0].arn]
    }
  }
}

# ===========================================
# IAM Role Policies (Attached to Roles)
# ===========================================

resource "aws_iam_role_policy" "publisher" {
  for_each = toset(var.publisher_role_names)

  name   = "${local.queue_name}-publisher"
  role   = each.value
  policy = data.aws_iam_policy_document.publisher.json
}

resource "aws_iam_role_policy" "consumer" {
  for_each = toset(var.consumer_role_names)

  name   = "${local.queue_name}-consumer"
  role   = each.value
  policy = data.aws_iam_policy_document.consumer.json
}

