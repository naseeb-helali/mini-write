variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "execution_role_arn" {
  type = string
}

variable "api_task_role_arn" {
  type = string
}

variable "worker_task_role_arn" {
  type = string
}

variable "api_image" {
  type = string
}

variable "worker_image" {
  type = string
}

variable "api_cpu" {
  type    = number
  default = 512
}

variable "api_memory" {
  type    = number
  default = 1024
}

variable "worker_cpu" {
  type    = number
  default = 1024
}

variable "worker_memory" {
  type    = number
  default = 2048
}

variable "api_container_port" {
  type    = number
  default = 80
}

variable "node_env" {
  type    = string
  default = "production"
}

variable "database_host" {
  type = string
}

variable "database_port" {
  type    = number
  default = 5432
}

variable "database_name" {
  type = string
}

variable "database_user" {
  type = string
}

variable "redis_host" {
  type = string
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "input_bucket_name" {
  type = string
}

variable "processed_bucket_name" {
  type = string
}

variable "application_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "api_desired_count" {
  type    = number
  default = 2
}

variable "worker_desired_count" {
  type    = number
  default = 1
}

variable "worker_concurrency" {
  type    = number
  default = 2
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "api_secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))

  default = []
}

variable "worker_secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))

  default = []
}

variable "api_target_group_arn" {
  description = "Target group ARN used by the API ECS service"
  type        = string
  default     = null
}

variable "api_container_name" {
  description = "API container name"
  type        = string
  default     = "api"
}
