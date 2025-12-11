output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "ALB URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = aws_security_group.ecs.id
}

output "alb_listener_arn" {
  description = "ALB HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

# ===========================================
# Sample API Service Outputs
# ===========================================

output "sampleapi_ecr_url" {
  description = "ECR repository URL for sampleapi"
  value       = module.sampleapi.ecr_repository_url
}

output "sampleapi_service_name" {
  description = "ECS service name for sampleapi"
  value       = module.sampleapi.service_name
}

output "sampleapi_task_definition_arn" {
  description = "Task definition ARN for sampleapi"
  value       = module.sampleapi.task_definition_arn
}

output "sampleapi_url" {
  description = "URL to access sampleapi via ALB"
  value       = "http://${aws_lb.main.dns_name}/api"
}

# ===========================================
# Sample Worker Service Outputs
# ===========================================

output "sampleworker_ecr_url" {
  description = "ECR repository URL for sampleworker"
  value       = module.sampleworker.ecr_repository_url
}

output "sampleworker_service_name" {
  description = "ECS service name for sampleworker"
  value       = module.sampleworker.service_name
}

output "sampleworker_task_definition_arn" {
  description = "Task definition ARN for sampleworker"
  value       = module.sampleworker.task_definition_arn
}

# ===========================================
# SQS Queue
# ===========================================

output "sqs_queue_url" {
  description = "SQS queue URL for task messages"
  value       = module.tasks_queue.queue_url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = module.tasks_queue.queue_arn
}

output "sqs_queue_name" {
  description = "SQS queue name"
  value       = module.tasks_queue.queue_name
}

output "sqs_dlq_url" {
  description = "SQS dead letter queue URL"
  value       = module.tasks_queue.dlq_url
}

output "sqs_dlq_arn" {
  description = "SQS dead letter queue ARN"
  value       = module.tasks_queue.dlq_arn
}

# ===========================================
# SES (Simple Email Service)
# ===========================================

output "ses_sender_email" {
  description = "SES sender email address"
  value       = aws_ses_email_identity.sender.email
}

output "ses_sender_arn" {
  description = "SES sender email identity ARN"
  value       = aws_ses_email_identity.sender.arn
}
