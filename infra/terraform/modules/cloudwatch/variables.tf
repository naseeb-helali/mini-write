variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "api_service_name" {
  description = "ECS API service name"
  type        = string
}

variable "worker_service_name" {
  description = "ECS Worker service name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix used by CloudWatch dimensions"
  type        = string
}

variable "api_target_group_arn_suffix" {
  description = "API target group ARN suffix used by CloudWatch dimensions"
  type        = string
}

variable "api_cpu_threshold" {
  description = "API CPU utilization alarm threshold"
  type        = number
  default     = 80
}

variable "api_memory_threshold" {
  description = "API memory utilization alarm threshold"
  type        = number
  default     = 80
}

variable "worker_cpu_threshold" {
  description = "Worker CPU utilization alarm threshold"
  type        = number
  default     = 80
}

variable "worker_memory_threshold" {
  description = "Worker memory utilization alarm threshold"
  type        = number
  default     = 80
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx request threshold"
  type        = number
  default     = 10
}

variable "target_5xx_threshold" {
  description = "Target 5xx request threshold"
  type        = number
  default     = 10
}

variable "unhealthy_host_threshold" {
  description = "Number of unhealthy API targets that triggers an alarm"
  type        = number
  default     = 1
}

variable "target_response_time_threshold" {
  description = "Target response time threshold in seconds"
  type        = number
  default     = 2
}

variable "evaluation_periods" {
  description = "Number of CloudWatch evaluation periods"
  type        = number
  default     = 2
}

variable "period_seconds" {
  description = "CloudWatch alarm evaluation period"
  type        = number
  default     = 60
}

variable "alarm_actions" {
  description = "Optional CloudWatch alarm action ARNs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}