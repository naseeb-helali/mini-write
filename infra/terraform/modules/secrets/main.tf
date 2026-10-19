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

# ==========================================
# 1. Database Secret & Value
# ==========================================
resource "aws_secretsmanager_secret" "database" {
  name                    = "${local.name_prefix}/database"
  description             = "Mini-Write database credentials."
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  
  # يفضل تمرير البيانات كـ JSON object لبيانات قاعدة البيانات
  secret_string = jsonencode({
    password = var.db_password
  })
}

# ==========================================
# 2. Redis Secret & Value
# ==========================================
resource "aws_secretsmanager_secret" "redis" {
  name                    = "${local.name_prefix}/redis"
  description             = "Mini-Write Redis credentials."
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/redis"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id

  secret_string = jsonencode({
    password = var.redis_password
  })
}

# ==========================================
# 3. JWT Secret & Value
# ==========================================
resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${local.name_prefix}/jwt"
  description             = "Mini-Write JWT signing secret."
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}/jwt"
    }
  )
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id

  secret_string = jsonencode({
    jwt_secret = var.jwt_secret
  })
}