variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling size in GiB."
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Initial database name."
  type        = string
}

variable "master_username" {
  description = "RDS master username."
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "RDS master password."
  type        = string
  sensitive   = true
}

variable "port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "subnet_ids" {
  description = "Private data subnet IDs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups attached to RDS."
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect database from accidental deletion."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destruction."
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Enable storage encryption."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}