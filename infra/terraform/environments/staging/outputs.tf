output "environment" {
  description = "Terraform environment."
  value       = var.environment
}

output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "project_name" {
  description = "Project name."
  value       = var.project_name
}




output "vpc_id" {
  description = "Staging VPC ID."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Staging public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Staging private application subnet IDs."
  value       = module.vpc.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "Staging private data subnet IDs."
  value       = module.vpc.private_data_subnet_ids
}

output "nat_gateway_ids" {
  description = "Staging NAT Gateway IDs."
  value       = module.vpc.nat_gateway_ids
}




output "alb_security_group_id" {
  description = "Security group ID for the public ALB."
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS workloads."
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS."
  value       = module.security_groups.rds_security_group_id
}

output "redis_security_group_id" {
  description = "Security group ID for ElastiCache Redis."
  value       = module.security_groups.redis_security_group_id
}




output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS application task role ARN."
  value       = module.iam.ecs_task_role_arn
}




output "ecr_repository_urls" {
  description = "ECR repository URLs."

  value = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs."

  value = module.ecr.repository_arns
}




output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint."

  value = module.rds.endpoint
}

output "rds_port" {
  description = "RDS PostgreSQL port."

  value = module.rds.port
}

output "rds_database_name" {
  description = "RDS database name."

  value = module.rds.database_name
}

output "rds_identifier" {
  description = "RDS instance identifier."

  value = module.rds.identifier
}




output "redis_endpoint" {
  description = "ElastiCache primary endpoint."

  value = module.elasticache.primary_endpoint_address
}

output "redis_port" {
  description = "ElastiCache port."

  value = module.elasticache.port
}

output "redis_replication_group_id" {
  description = "ElastiCache replication group ID."

  value = module.elasticache.id
}




output "s3_bucket_names" {
  description = "S3 bucket names keyed by logical purpose."

  value = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "S3 bucket ARNs keyed by logical purpose."

  value = module.s3.bucket_arns
}