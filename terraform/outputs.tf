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
# ECR Repositories (Dynamic)
# ===========================================

output "ecr_repository_urls" {
  description = "ECR repository URLs for all services"
  value = {
    for name, repo in aws_ecr_repository.services :
    name => repo.repository_url
  }
}

# ===========================================
# ECS Services (Dynamic)
# ===========================================

output "service_names" {
  description = "ECS service names for all services"
  value = {
    for name, service in aws_ecs_service.services :
    name => service.name
  }
}

output "task_definition_arns" {
  description = "Task definition ARNs for all services"
  value = {
    for name, task in aws_ecs_task_definition.services :
    name => task.arn
  }
}

# ===========================================
# Service URLs (for API services)
# ===========================================

output "service_urls" {
  description = "URLs to access API services via ALB"
  value = {
    for name, config in local.api_services :
    name => "http://${aws_lb.main.dns_name}${config.load_balancer.path_patterns[0]}"
  }
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

