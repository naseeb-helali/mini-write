variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs accessible by ECS task execution role."
  type        = list(string)
  default     = []
}

variable "log_group_arns" {
  description = "CloudWatch Logs ARNs accessible by ECS task execution role."
  type        = list(string)
  default     = []
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN used by the application."
  type        = string
  default     = ""
}

variable "enable_s3_access" {
  description = "Whether ECS application tasks require S3 access."
  type        = bool
  default     = false
}