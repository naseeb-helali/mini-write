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

output "ci_runner_role_arn" {
  description = "CI runner IAM role ARN (for ECR push, etc.)."
  value       = try(aws_iam_role.ci_runner[0].arn, null)
}

output "cd_runner_role_arn" {
  description = "CD runner IAM role ARN (for ECR pull + ECS deploy)."
  value       = try(aws_iam_role.cd_runner[0].arn, null)
}