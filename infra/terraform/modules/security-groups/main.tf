locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ==========================================================
# ALB SECURITY GROUP
# ==========================================================

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for the public Application Load Balancer."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
      Tier = "edge"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset([
    for cidr in var.alb_ingress_cidr_blocks :
    "${cidr}:80"
  ])

  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = split(":", each.value)[0]
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  description = "HTTP access to public ALB."
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset([
    for cidr in var.alb_ingress_cidr_blocks :
    "${cidr}:443"
  ])

  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = split(":", each.value)[0]
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "HTTPS access to public ALB."
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow ALB outbound traffic."
}

# ==========================================================
# ECS SECURITY GROUP
# ==========================================================

resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS workloads."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-sg"
      Tier = "application"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id

  referenced_security_group_id = aws_security_group.alb.id

  from_port   = var.ecs_ingress_port
  to_port     = var.ecs_ingress_port
  ip_protocol = "tcp"

  description = "Allow application traffic from ALB only."
}

resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow ECS outbound traffic to dependencies and AWS services."
}

# ==========================================================
# RDS SECURITY GROUP
# ==========================================================

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for PostgreSQL RDS."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
      Tier = "data"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id = aws_security_group.rds.id

  referenced_security_group_id = aws_security_group.ecs.id

  from_port   = var.rds_port
  to_port     = var.rds_port
  ip_protocol = "tcp"

  description = "Allow PostgreSQL traffic from ECS only."
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow RDS outbound traffic."
}

# ==========================================================
# REDIS SECURITY GROUP
# ==========================================================

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-redis-sg"
      Tier = "data"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id = aws_security_group.redis.id

  referenced_security_group_id = aws_security_group.ecs.id

  from_port   = var.redis_port
  to_port     = var.redis_port
  ip_protocol = "tcp"

  description = "Allow Redis traffic from ECS only."
}

resource "aws_vpc_security_group_egress_rule" "redis_all" {
  security_group_id = aws_security_group.redis.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow Redis outbound traffic."
}