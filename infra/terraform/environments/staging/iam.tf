module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  enable_s3_access = false
}