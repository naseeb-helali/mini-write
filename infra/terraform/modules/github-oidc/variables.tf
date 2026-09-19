variable "project" {
  description = "Project name."
  type        = string
}

variable "plan_subjects" {
  description = "GitHub OIDC subjects allowed to assume the Terraform plan role."
  type        = list(string)

  validation {
    condition     = length(var.plan_subjects) > 0
    error_message = "At least one GitHub OIDC plan subject must be provided."
  }
}

variable "apply_subject" {
  description = "GitHub OIDC subject allowed to assume the Terraform apply role."
  type        = string

  validation {
    condition     = length(trimspace(var.apply_subject)) > 0
    error_message = "The GitHub OIDC apply subject must not be empty."
  }
}

variable "tags" {
  description = "Tags applied to OIDC IAM resources."
  type        = map(string)
  default     = {}
}

variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state."
  type        = string
}

variable "aws_region" {
  description = "Name of the S3 bucket storing Terraform state."
  type        = string
  default = "us-east-1"
}

variable "environment" {
  description = "Name of the S3 bucket storing Terraform state."
  type        = string
  default = "staging"
}




variable "ci_subjects" {
  description = "GitHub OIDC subjects allowed to assume the CI runner role (for ECR push, etc.)."
  type        = list(string)
  default     = []
}


variable "cd_subjects" {
  description = "GitHub OIDC subjects allowed to assume the CD runner role (for ECR pull + ECS deploy)."
  type        = list(string)
  default     = []
}