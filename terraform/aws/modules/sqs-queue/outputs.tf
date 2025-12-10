# ===========================================
# Queue Outputs
# ===========================================

output "queue_id" {
  description = "SQS queue ID (URL)"
  value       = aws_sqs_queue.this.id
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "SQS queue name"
  value       = aws_sqs_queue.this.name
}

# ===========================================
# Dead Letter Queue Outputs
# ===========================================

output "dlq_id" {
  description = "DLQ ID (URL)"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "DLQ URL"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_name" {
  description = "DLQ name"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].name : null
}

# ===========================================
# IAM Policy Documents
# ===========================================

output "publisher_policy_json" {
  description = "IAM policy JSON for publishers"
  value       = data.aws_iam_policy_document.publisher.json
}

output "consumer_policy_json" {
  description = "IAM policy JSON for consumers"
  value       = data.aws_iam_policy_document.consumer.json
}

