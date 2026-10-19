module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  environment  = var.environment

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  redis_password = var.redis_password
  jwt_secret = var.jwt_secret
  db_password = var.db_password
}