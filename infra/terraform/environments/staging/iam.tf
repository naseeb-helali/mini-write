module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region = var.aws_region
  
  input_bucket_arn     = module.s3.bucket_arns["input"]
  processed_bucket_arn = module.s3.bucket_arns["processed"]

  enable_s3_access = false
}