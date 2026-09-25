module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment

  bucket_names = {
    input     = "${var.project_name}-${var.environment}-input"
    processed = "${var.project_name}-${var.environment}-processed"
  }

  force_destroy = false

  enable_versioning = true

  noncurrent_version_expiration_days = 30
}
