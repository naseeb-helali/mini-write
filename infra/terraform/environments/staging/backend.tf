terraform {
  backend "s3" {
    bucket       = "mini-write-terraform-state54913687"
    key          = "mini-write/staging/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}