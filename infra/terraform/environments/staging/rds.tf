module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  identifier = "${var.project_name}-${var.environment}-postgres"

  database_name   = var.postgres_database
  master_username = var.postgres_username
  master_password = var.postgres_password

  subnet_ids = module.vpc.private_data_subnet_ids

  security_group_ids = [
    module.security_groups.rds_security_group_id
  ]

  engine_version = "16"

  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100

  multi_az = true

  backup_retention_period = 0

  storage_encrypted = true

  deletion_protection = true
  skip_final_snapshot = false
}