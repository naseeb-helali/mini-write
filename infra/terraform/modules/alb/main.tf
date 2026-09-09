locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ==============================================================================
# ALB Security Group
# ==============================================================================

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "Security group for the Mini-Write Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# HTTP ingress
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  description = "Allow HTTP traffic from the Internet"
}

# ALB outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow outbound traffic from ALB"
}

# ==============================================================================
# Application Load Balancer
# ==============================================================================

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
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