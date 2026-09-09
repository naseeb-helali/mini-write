terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_TERRAFORM_STATE_BUCKET"
    key          = "mini-write/production/terraform.tfstate"
    region       = "REPLACE_WITH_AWS_REGION"
    use_lockfile = true
    encrypt      = true
  }
}