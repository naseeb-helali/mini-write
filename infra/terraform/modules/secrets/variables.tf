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