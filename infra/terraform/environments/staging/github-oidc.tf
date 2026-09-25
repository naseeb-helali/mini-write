module "github_oidc" {
  source = "../../modules/github-oidc"

  project = var.project_name
  project_name = var.project_name

  tfstate_bucket_name = "mini-write-terraform-state54913687"

  plan_subjects = [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
    "repo:${var.github_repository}:environment:staging"
  ]

  apply_subject = "repo:${var.github_repository}:environment:staging"

  # CI subjects (ECR push only)
  ci_subjects = [
    "repo:${var.github_repository}:ref:refs/heads/main",
    "repo:${var.github_repository}:environment:staging"
  ]

  # CD subjects (ECR pull + ECS deploy)
  cd_subjects = [
    "repo:${var.github_repository}:ref:refs/heads/main",
    "repo:${var.github_repository}:environment:staging",
    "repo:${var.github_repository}:environment:production"
  ]

  tags = {
    Project     = "mini-write"
    Environment = "staging"
    ManagedBy   = "terraform"
    Component   = "github-oidc"
  }
}