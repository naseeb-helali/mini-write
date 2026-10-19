variable "k8s_ubuntu_ami_id" {
  description = "Optional pinned Ubuntu 24.04 amd64 AMI ID."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "k8s_ubuntu_ami_ssm_parameter" {
  description = "Canonical public SSM parameter for the current Ubuntu Server 24.04 LTS amd64 gp3 AMI."
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

variable "k8s_control_plane_instance_type" {
  description = "EC2 instance type for the Kubernetes control-plane node."
  type        = string
  default     = "t3.small"
}

variable "k8s_worker_instance_type" {
  description = "EC2 instance type for Kubernetes worker nodes."
  type        = string
  default     = "t3.micro"
}

variable "k8s_control_plane_root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB for the control-plane node."
  type        = number
  default     = 40

  validation {
    condition     = var.k8s_control_plane_root_volume_size >= 30
    error_message = "The Kubernetes control-plane root volume must be at least 30 GiB."
  }
}

variable "k8s_worker_root_volume_size" {
  description = "Encrypted gp3 root volume size in GiB for each worker node."
  type        = number
  default     = 50

  validation {
    condition     = var.k8s_worker_root_volume_size >= 30
    error_message = "Each Kubernetes worker root volume must be at least 30 GiB."
  }
}
