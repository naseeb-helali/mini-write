variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "aws_region" {
  description = "AWS Region hosting the Kubernetes nodes."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs used by the dedicated Kubernetes ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "The Kubernetes ALB requires at least two public subnets."
  }
}

variable "private_app_subnet_ids" {
  description = "Existing private application subnet IDs used by Kubernetes nodes."
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_ids) >= 2
    error_message = "The Kubernetes cluster requires at least two private application subnets."
  }
}

variable "ecr_repository_arns" {
  description = "Existing ECR repository ARNs from which Kubernetes nodes pull application images."
  type        = list(string)
}

variable "input_bucket_arn" {
  description = "Existing Mini-Write input S3 bucket ARN."
  type        = string
}

variable "processed_bucket_arn" {
  description = "Existing Mini-Write processed S3 bucket ARN."
  type        = string
}

variable "secrets_manager_arns" {
  description = "Existing Mini-Write Secrets Manager secret ARNs required by workloads."
  type        = list(string)
}

variable "ubuntu_ami_id" {
  description = "Optional explicitly pinned Ubuntu 24.04 amd64 AMI ID."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "ubuntu_ami_ssm_parameter" {
  description = "Canonical SSM public parameter used to resolve Ubuntu 24.04 amd64."
  type        = string
}

variable "control_plane_instance_type" {
  description = "Control-plane EC2 instance type."
  type        = string
}

variable "worker_instance_type" {
  description = "Worker EC2 instance type."
  type        = string
}

variable "control_plane_root_volume_size" {
  description = "Control-plane encrypted gp3 root volume size in GiB."
  type        = number
}

variable "worker_root_volume_size" {
  description = "Worker encrypted gp3 root volume size in GiB."
  type        = number
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}
