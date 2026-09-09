variable "project_name" {
  description = "Project name."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "repository_names" {
  description = "Container repositories to create."
  type        = set(string)
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten."
  type        = string

  default = "IMMUTABLE"

  validation {
    condition = contains(
      ["MUTABLE", "IMMUTABLE"],
      var.image_tag_mutability
    )

    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push."
  type        = bool
  default     = true
}