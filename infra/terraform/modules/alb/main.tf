locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ==============================================================================
# Application Load Balancer
# ==============================================================================

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    var.alb_security_group_id
  ]

  subnets = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# ==============================================================================
# Target Group
# ==============================================================================

resource "aws_lb_target_group" "api" {
  name = "${local.name_prefix}-api"

  port        = var.api_container_port
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = var.vpc_id

  health_check {
    enabled = true

    protocol = "HTTP"
    path     = var.health_check_path

    port = "traffic-port"

    healthy_threshold   = 2
    unhealthy_threshold = 3

    timeout  = 5
    interval = 30

    matcher = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-api-targets"
    }
  )
}

# ==============================================================================
# HTTP Listener
# ==============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.api.arn
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-http-listener"
    }
  )
}