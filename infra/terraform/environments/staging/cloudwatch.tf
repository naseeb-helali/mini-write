module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  ecs_cluster_name = module.ecs.cluster_name

  api_service_name    = module.ecs.api_service_name
  worker_service_name = module.ecs.worker_service_name

  alb_arn_suffix = module.alb.alb_arn_suffix

  api_target_group_arn_suffix = module.alb.target_group_arn_suffix

  api_cpu_threshold = 80

  api_memory_threshold = 80

  worker_cpu_threshold = 80

  worker_memory_threshold = 80

  alb_5xx_threshold = 10

  target_5xx_threshold = 10

  unhealthy_host_threshold = 1

  target_response_time_threshold = 2

  evaluation_periods = 2

  period_seconds = 60
}