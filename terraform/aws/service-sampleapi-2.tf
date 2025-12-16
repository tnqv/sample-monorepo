# ===========================================
# Sample API Service
# ===========================================
# Infrastructure is managed by Terraform
# Container definitions are managed by CI/CD via Jsonnet
# See: task-definitions/sampleapi.jsonnet

locals {
  # Environment-specific configuration
  sampleapi_2_config = {
    staging = {
      # Container Configuration
      cpu            = 256
      memory         = 512
      container_port = 8080
      desired_count  = 1

      # Auto Scaling
      enable_autoscaling = true
      min_count          = 1
      max_count          = 2
      cpu_target_value   = 70

      # Load Balancer
      lb_priority       = 100
      lb_path_patterns  = ["/api/*", "/health"]
      health_check_path = "/health"
    }

    prod = {
      # Container Configuration
      cpu            = 512
      memory         = 1024
      container_port = 8080
      desired_count  = 2

      # Auto Scaling
      enable_autoscaling = true
      min_count          = 2
      max_count          = 10
      cpu_target_value   = 60

      # Load Balancer
      lb_priority       = 100
      lb_path_patterns  = ["/api/*", "/health"]
      health_check_path = "/health"
    }
  }

  # Select config based on environment (default to staging if not found)
  sampleapi_2 = lookup(local.sampleapi_2_config, var.environment, local.sampleapi_2_config["staging"])
}

module "sampleapi_2" {
  source = "./modules/ecs-fargate-service"

  # Basic Configuration
  name         = "sampleapi_2"
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
  container_port = local.sampleapi.container_port
  cpu            = local.sampleapi.cpu
  memory         = local.sampleapi.memory
  desired_count  = local.sampleapi.desired_count

  # Load Balancer
  enable_load_balancer      = true
  lb_listener_arn           = aws_lb_listener.http.arn
  lb_listener_rule_priority = local.sampleapi.lb_priority
  lb_path_patterns          = local.sampleapi.lb_path_patterns
  lb_health_check_path      = local.sampleapi.health_check_path

  # Auto Scaling
  enable_autoscaling = local.sampleapi.enable_autoscaling
  min_count          = local.sampleapi.min_count
  max_count          = local.sampleapi.max_count
  cpu_target_value   = local.sampleapi.cpu_target_value

  # Dummy environment variables (CI/CD manages actual values via Jsonnet)
  environment_variables = [
    { name = "PLACEHOLDER", value = "managed-by-cicd" }
  ]

  tags = {
    Service   = "sampleapi_2"
    Component = "api"
  }
}
