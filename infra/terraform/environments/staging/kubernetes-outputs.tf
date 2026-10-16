output "kubernetes_node_instance_ids" {
  description = "Kubernetes EC2 instance IDs keyed by node role."
  value       = module.kubernetes_ec2.node_instance_ids
}

output "kubernetes_node_private_ips" {
  description = "Private IP addresses of the Kubernetes EC2 nodes."
  value       = module.kubernetes_ec2.node_private_ips
}

output "kubernetes_node_instance_arns" {
  description = "EC2 instance ARNs for the Kubernetes nodes."
  value       = module.kubernetes_ec2.node_instance_arns
}

output "kubernetes_node_security_group_id" {
  description = "Security Group ID attached to the Kubernetes EC2 nodes."
  value       = module.kubernetes_ec2.node_security_group_id
}

output "kubernetes_node_role_arn" {
  description = "EC2 instance role ARN for Kubernetes nodes."
  value       = module.kubernetes_ec2.node_role_arn
}

output "kubernetes_node_instance_profile_name" {
  description = "EC2 instance profile name attached to Kubernetes nodes."
  value       = module.kubernetes_ec2.node_instance_profile_name
}

output "kubernetes_alb_dns_name" {
  description = "DNS name of the dedicated Kubernetes Application Load Balancer."
  value       = module.kubernetes_ec2.alb_dns_name
}

output "kubernetes_alb_arn" {
  description = "ARN of the dedicated Kubernetes Application Load Balancer."
  value       = module.kubernetes_ec2.alb_arn
}

output "kubernetes_target_group_arn" {
  description = "ARN of the Kubernetes worker instance target group."
  value       = module.kubernetes_ec2.target_group_arn
}

output "kubernetes_ansible_transfer_bucket" {
  description = "S3 bucket used by the Ansible SSM connection plugin for file transfer."
  value       = aws_s3_bucket.kubernetes_ansible_transfer.bucket
}

output "kubernetes_bootstrap_role_arn" {
  description = "GitHub OIDC role ARN for Kubernetes Ansible bootstrap."
  value       = aws_iam_role.kubernetes_bootstrap.arn
}

output "kubernetes_cd_role_arn" {
  description = "GitHub OIDC role ARN for Kubernetes deployment."
  value       = aws_iam_role.kubernetes_cd.arn
}
