module "ecs" {
  source = "../../modules/ecs"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region


api_secrets = [
  {
    name      = "POSTGRES_PASSWORD"
    valueFrom = "${module.secrets.database_secret_arn}:password::"
  },
  {
    name      = "REDIS_PASSWORD"
    valueFrom = "${module.secrets.redis_secret_arn}:password::"
  },
  {
    name      = "JWT_SECRET"
    valueFrom = "${module.secrets.jwt_secret_arn}:jwt_secret::"
  }
]


worker_secrets = [
  {
    name      = "POSTGRES_PASSWORD"
    valueFrom = "${module.secrets.database_secret_arn}:password::"
  },
  {
    name      = "REDIS_PASSWORD"
    valueFrom = "${module.secrets.redis_secret_arn}:password::"
  }
]

  execution_role_arn   = module.iam.ecs_task_execution_role_arn
  api_task_role_arn    = module.iam.api_task_role_arn
  worker_task_role_arn = module.iam.worker_task_role_arn

api_image = "${module.ecr.repository_urls["mini-write-api"]}:latest"
worker_image = "${module.ecr.repository_urls["mini-write-worker"]}:latest"

  application_subnet_ids = module.vpc.private_app_subnet_ids

  ecs_security_group_id = module.security_groups.ecs_security_group_id

  database_host = module.rds.endpoint
  database_port = module.rds.port
  database_name = module.rds.database_name
  database_user = module.rds.username

  redis_host = module.elasticache.primary_endpoint_address
  redis_port = module.elasticache.port

  input_bucket_name     = module.s3.bucket_names["input"]
  processed_bucket_name = module.s3.bucket_names["processed"]

  api_desired_count    = 1
  worker_desired_count = 1

  api_target_group_arn = module.alb.target_group_arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}