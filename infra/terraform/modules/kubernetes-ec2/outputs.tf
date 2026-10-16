output "node_security_group_id" {
  description = "Security Group ID attached to all Kubernetes nodes."
  value       = aws_security_group.kubernetes_nodes.id
}

output "alb_security_group_id" {
  description = "Security Group ID attached to the dedicated Kubernetes ALB."
  value       = aws_security_group.kubernetes_alb.id
}

output "node_role_arn" {
  description = "EC2 instance role ARN attached to Kubernetes nodes."
  value       = aws_iam_role.kubernetes_nodes.arn
}

output "node_role_name" {
  description = "EC2 instance role name attached to Kubernetes nodes."
  value       = aws_iam_role.kubernetes_nodes.name
}

output "node_instance_profile_name" {
  description = "EC2 instance profile name attached to Kubernetes nodes."
  value       = aws_iam_instance_profile.kubernetes_nodes.name
}

output "node_instance_ids" {
  description = "EC2 instance IDs keyed by Kubernetes node role."
  value       = { for key, instance in aws_instance.kubernetes_nodes : key => instance.id }
}

output "node_instance_arns" {
  description = "EC2 instance ARNs for all Kubernetes nodes."
  value       = [for instance in values(aws_instance.kubernetes_nodes) : instance.arn]
}

output "node_private_ips" {
  description = "Private IP addresses keyed by Kubernetes node role."
  value       = { for key, instance in aws_instance.kubernetes_nodes : key => instance.private_ip }
}

output "control_plane_instance_id" {
  description = "Control-plane EC2 instance ID."
  value       = aws_instance.kubernetes_nodes["control_plane"].id
}

output "control_plane_instance_arn" {
  description = "Control-plane EC2 instance ARN."
  value       = aws_instance.kubernetes_nodes["control_plane"].arn
}

output "control_plane_private_ip" {
  description = "Control-plane private IP address."
  value       = aws_instance.kubernetes_nodes["control_plane"].private_ip
}

output "alb_arn" {
  description = "Dedicated Kubernetes ALB ARN."
  value       = aws_lb.kubernetes.arn
}

output "alb_dns_name" {
  description = "Dedicated Kubernetes ALB DNS name."
  value       = aws_lb.kubernetes.dns_name
}

output "target_group_arn" {
  description = "Kubernetes worker target group ARN."
  value       = aws_lb_target_group.kubernetes_workers.arn
}
