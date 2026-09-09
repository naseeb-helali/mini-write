variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the security groups will be created."
  type        = string
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the public ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_ingress_ports" {
  description = "Ports exposed by the public ALB."
  type        = list(number)
  default     = [80, 443]
}

variable "ecs_ingress_port" {
  description = "Port exposed by ECS services to the ALB."
  type        = number
  default     = 80
}

variable "rds_port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "redis_port" {
  description = "Redis port."
  type        = number
  default     = 6379
}