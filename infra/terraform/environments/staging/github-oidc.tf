module "github_oidc" {
  source = "../../modules/github-oidc"

  project = "mini-write"

  tfstate_bucket_name = "mini-write-terraform-state54913687"

  plan_subjects = [
    "repo:${var.github_repository}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
    "repo:${var.github_repository}:environment:staging"
  ]

  apply_subject = "repo:${var.github_repository}:environment:staging"

  tags = {
    Project     = "mini-write"
    Environment = "staging"
    ManagedBy   = "terraform"
    Component   = "github-oidc"
  }
}