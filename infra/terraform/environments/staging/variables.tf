variable "aws_region" {
  description = "AWS region for the environment."
  type        = string
}

variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the staging VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones for staging."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Staging requires at least two Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs."
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "Private data subnet CIDRs."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway for staging."
  type        = bool
  default     = true
}




variable "postgres_database" {
  description = "PostgreSQL database name."
  type        = string
}

variable "postgres_username" {
  description = "PostgreSQL master username."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL master password."
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}




variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.micro"
}




variable "github_repository" {
  description = "GitHub repository in OWNER/REPOSITORY format."
  type        = string

  validation {
    condition = can(
      regex(
        "^[^/]+/[^/]+$",
        var.github_repository
      )
    )

    error_message = "github_repository must use OWNER/REPOSITORY format."
  }
}