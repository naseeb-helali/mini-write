module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_names = [
    "mini-write-api",
    "mini-write-worker"
  ]

  image_tag_mutability = "IMMUTABLE"

  scan_on_push = false
} 