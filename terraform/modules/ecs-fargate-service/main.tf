# ===========================================
# Local Values
# ===========================================

locals {
  resource_name = "${var.project_name}-${var.environment}-${var.name}"
  
  # Construct container image URL from ECR repository
  container_image = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
  
  common_tags = merge(var.tags, {
    Name        = local.resource_name
    Environment = var.environment
    Service     = var.name
    ManagedBy   = "terraform"
  })

  # Build container definition
  container_definition = {
    name      = var.name
    image     = local.container_image
    essential = true

    portMappings = var.container_port != null ? [
      {
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }
    ] : []

    environment = var.environment_variables
    secrets     = var.secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = var.name
      }
    }

    healthCheck = var.health_check_command != null ? {
      command     = var.health_check_command
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    } : null
  }
}

# ===========================================
# ECR Repository
# ===========================================

resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}/${var.environment}/${var.name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ===========================================
# ECS Task Definition
# ===========================================

resource "aws_ecs_task_definition" "this" {
  family                   = local.resource_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # Initial dummy container definition - CI/CD will manage actual deployments
  container_definitions = jsonencode([local.container_definition])

  tags = local.common_tags

  # Ignore container_definitions changes - managed by CI/CD via Jsonnet
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# ===========================================
# ECS Service
# ===========================================

resource "aws_ecs_service" "this" {
  name            = local.resource_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = local.common_tags

  depends_on = [aws_lb_listener_rule.this]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ===========================================
# Load Balancer Resources (Optional)
# ===========================================

resource "aws_lb_target_group" "this" {
  count = var.enable_load_balancer ? 1 : 0

  name        = substr(local.resource_name, 0, 32) # TG name max 32 chars
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.lb_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "this" {
  count = var.enable_load_balancer ? 1 : 0

  listener_arn = var.lb_listener_arn
  priority     = var.lb_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = var.lb_path_patterns
    }
  }

  tags = local.common_tags
}

# ===========================================
# Auto Scaling (Optional)
# ===========================================

resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${split("/", var.cluster_id)[1]}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.resource_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

