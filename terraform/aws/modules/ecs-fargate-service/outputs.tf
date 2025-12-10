# ===========================================
# ECR Outputs
# ===========================================

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.this.arn
}

# ===========================================
# ECS Task Definition Outputs
# ===========================================

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Task definition revision"
  value       = aws_ecs_task_definition.this.revision
}

# ===========================================
# ECS Service Outputs
# ===========================================

output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.id
}

# ===========================================
# Load Balancer Outputs
# ===========================================

output "target_group_arn" {
  description = "Target group ARN (if load balancer enabled)"
  value       = var.enable_load_balancer ? aws_lb_target_group.this[0].arn : null
}

output "target_group_name" {
  description = "Target group name (if load balancer enabled)"
  value       = var.enable_load_balancer ? aws_lb_target_group.this[0].name : null
}

