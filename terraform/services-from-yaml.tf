# ===========================================
# Dynamic Service Provisioning from YAML
# ===========================================
# This file reads service.yaml from each service directory
# and provisions ECS services based on developer configuration.

# ===========================================
# Read Service Definitions
# ===========================================

locals {
  # List of services to provision (directories under cmd/)
  service_names = [
    "sampleapi",
    "sampleworker"
  ]

  # Read and decode YAML for each service
  services = {
    for name in local.service_names :
    name => yamldecode(file("${path.module}/../cmd/${name}/service.yaml"))
  }

  # Separate API services (with load balancer) from workers
  api_services = {
    for name, config in local.services :
    name => config
    if lookup(config.load_balancer, "enabled", false) == true
  }

  worker_services = {
    for name, config in local.services :
    name => config
    if lookup(config.load_balancer, "enabled", false) == false
  }

  # Compute container image URLs for each service
  # ECR repository name matches service name: {project}/{env}/{service_name}
  # Image tag is managed by CI/CD pipeline (var.image_tag)
  service_images = {
    for name, config in local.services :
    name => "${aws_ecr_repository.services[name].repository_url}:${var.image_tag}"
  }
}

# ===========================================
# ECR Repositories
# ===========================================

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "${var.project_name}/${var.environment}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-${each.key}"
      Environment = var.environment
      Service     = each.key
    },
    lookup(each.value, "tags", {})
  )
}

# ===========================================
# ECS Task Definitions
# ===========================================

resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.project_name}-${var.environment}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.container.cpu
  memory                   = each.value.container.memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    merge(
      {
        name      = each.key
        image     = local.service_images[each.key]
        essential = true

        portMappings = lookup(each.value.container, "port", null) != null ? [
          {
            containerPort = each.value.container.port
            hostPort      = each.value.container.port
            protocol      = "tcp"
          }
        ] : []

        environment = concat(
          [for k, v in lookup(each.value, "environment", {}) : { name = k, value = tostring(v) }],
          lookup(lookup(each.value, "sqs", {}), "publisher", false) || lookup(lookup(each.value, "sqs", {}), "consumer", false) ? [
            { name = "SQS_QUEUE_URL", value = module.tasks_queue.queue_url },
            { name = "AWS_REGION", value = var.aws_region }
          ] : [],
          lookup(lookup(each.value, "sqs", {}), "consumer", false) ? [
            { name = "SQS_DLQ_URL", value = module.tasks_queue.dlq_url }
          ] : [],
          [
            { name = "ENVIRONMENT", value = var.environment }
          ]
        )

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = each.key
          }
        }
      },
      # Only include healthCheck for services with a port (API services)
      lookup(each.value.container, "port", null) != null ? {
        healthCheck = {
          command     = lookup(each.value.container, "health_check_command", ["CMD-SHELL", "wget -q --spider http://localhost:${each.value.container.port}${lookup(each.value.container, "health_check_path", "/health")} || exit 1"])
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        }
      } : {}
    )
  ])

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-${each.key}"
      Environment = var.environment
      Service     = each.key
    },
    lookup(each.value, "tags", {})
  )
}

# ===========================================
# ECS Services
# ===========================================

resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = "${var.project_name}-${var.environment}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.scaling.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = lookup(each.value.load_balancer, "enabled", false) ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.services[each.key].arn
      container_name   = each.key
      container_port   = each.value.container.port
    }
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-${each.key}"
      Environment = var.environment
      Service     = each.key
    },
    lookup(each.value, "tags", {})
  )

  depends_on = [aws_lb_listener_rule.services]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ===========================================
# Target Groups (for API services only)
# ===========================================

resource "aws_lb_target_group" "services" {
  for_each = local.api_services

  name        = substr("${var.project_name}-${var.environment}-${each.key}", 0, 32)
  port        = each.value.container.port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = lookup(each.value.load_balancer.health_check, "healthy_threshold", 2)
    unhealthy_threshold = lookup(each.value.load_balancer.health_check, "unhealthy_threshold", 3)
    timeout             = lookup(each.value.load_balancer.health_check, "timeout", 5)
    interval            = lookup(each.value.load_balancer.health_check, "interval", 30)
    path                = lookup(each.value.load_balancer.health_check, "path", "/health")
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-tg"
    Environment = var.environment
    Service     = each.key
  }
}

# ===========================================
# ALB Listener Rules (for API services only)
# ===========================================

resource "aws_lb_listener_rule" "services" {
  for_each = local.api_services

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.load_balancer.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.load_balancer.path_patterns
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}-rule"
    Environment = var.environment
    Service     = each.key
  }
}

# ===========================================
# Auto Scaling
# ===========================================

resource "aws_appautoscaling_target" "services" {
  for_each = {
    for name, config in local.services :
    name => config
    if lookup(config.scaling, "autoscaling_enabled", false) == true
  }

  max_capacity       = each.value.scaling.max_count
  min_capacity       = each.value.scaling.min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "services_cpu" {
  for_each = {
    for name, config in local.services :
    name => config
    if lookup(config.scaling, "autoscaling_enabled", false) == true
  }

  name               = "${var.project_name}-${var.environment}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = each.value.scaling.cpu_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

