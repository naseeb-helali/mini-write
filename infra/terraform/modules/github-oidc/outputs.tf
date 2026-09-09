output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "iac_plan_role_arn" {
  description = "Terraform plan IAM role ARN."
  value       = aws_iam_role.iac_plan.arn
}

output "iac_apply_role_arn" {
  description = "Terraform apply IAM role ARN."
  value       = aws_iam_role.iac_apply.arn
}