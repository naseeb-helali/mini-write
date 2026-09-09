locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_secretsmanager_secret" "database" {
  name = "${local.name_prefix}/database"

  description = "Mini-Write database credentials."

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/database"
    }
  )
}

resource "aws_secretsmanager_secret" "redis" {
  name = "${local.name_prefix}/redis"

  description = "Mini-Write Redis credentials."

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/redis"
    }
  )
}

resource "aws_secretsmanager_secret" "jwt" {
  name = "${local.name_prefix}/jwt"

  description = "Mini-Write JWT signing secret."

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/jwt"
    }
  )
}