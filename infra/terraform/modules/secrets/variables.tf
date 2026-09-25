variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "recovery_window_in_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}
variable "redis_password" {
  type      = string
  sensitive = true
}