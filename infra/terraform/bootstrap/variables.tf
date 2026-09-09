variable "aws_region" {
  description = "AWS region used for Terraform bootstrap resources."
  type        = string
}

variable "project_name" {
  description = "Project name."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform state."
  type        = string
}