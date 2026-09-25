variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB is deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used by the ALB"
  type        = list(string)
}

variable "api_container_port" {
  description = "Port exposed by the API container"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "API health check path"
  type        = string
  default     = "/health/ready"
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
variable "alb_security_group_id" {
  description = "Security group ID attached to the Application Load Balancer."
  type        = string
}