module "github_oidc" {
  source = "../../modules/github-oidc"

  project = "mini-write"

  plan_subjects = [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main"
  ]

  apply_subject = "repo:${var.github_repository}:environment:staging-infrastructure"

  tags = {
    Project     = "mini-write"
    Environment = "staging"
    ManagedBy   = "terraform"
    Component   = "github-oidc"
  }
}