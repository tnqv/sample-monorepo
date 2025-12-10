# ===========================================
# Sample Worker Service
# ===========================================
# Infrastructure is managed by Terraform
# Container definitions are managed by CI/CD via Jsonnet
# See: task-definitions/sampleworker.jsonnet

locals {
  # Environment-specific configuration
  sampleworker_config = {
    staging = {
      # Container Configuration
      cpu           = 256
      memory        = 512
      desired_count = 1

      # Auto Scaling
      enable_autoscaling = true
      min_count          = 1
      max_count          = 2
      cpu_target_value   = 70
    }

    prod = {
      # Container Configuration
      cpu           = 512
      memory        = 1024
      desired_count = 2

      # Auto Scaling
      enable_autoscaling = true
      min_count          = 2
      max_count          = 8
      cpu_target_value   = 60
    }
  }

  # Select config based on environment (default to staging if not found)
  sampleworker = lookup(local.sampleworker_config, var.environment, local.sampleworker_config["staging"])
}

module "sampleworker" {
  source = "./modules/ecs-fargate-service"

  # Basic Configuration
  name         = "sampleworker"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Infrastructure References
  cluster_id         = aws_ecs_cluster.main.id
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs.id]
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  log_group_name     = aws_cloudwatch_log_group.ecs.name

  # Container Configuration (initial/dummy - CI/CD manages actual values)
  image_tag      = "latest"
  container_port = null  # Worker has no port
  cpu            = local.sampleworker.cpu
  memory         = local.sampleworker.memory
  desired_count  = local.sampleworker.desired_count

  # No Load Balancer for workers
  enable_load_balancer = false

  # Auto Scaling
  enable_autoscaling = local.sampleworker.enable_autoscaling
  min_count          = local.sampleworker.min_count
  max_count          = local.sampleworker.max_count
  cpu_target_value   = local.sampleworker.cpu_target_value

  # Dummy environment variables (CI/CD manages actual values via Jsonnet)
  environment_variables = [
    { name = "PLACEHOLDER", value = "managed-by-cicd" }
  ]

  tags = {
    Service   = "sampleworker"
    Component = "worker"
  }
}
