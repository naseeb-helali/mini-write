aws_region  = "us-east-1"
project_name = "mini-write"
environment = "staging"

vpc_cidr = "10.20.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

public_subnet_cidrs = [
  "10.20.0.0/24",
  "10.20.1.0/24"
]

private_app_subnet_cidrs = [
  "10.20.10.0/24",
  "10.20.11.0/24"
]

private_data_subnet_cidrs = [
  "10.20.20.0/24",
  "10.20.21.0/24"
]

enable_nat_gateway = true

single_nat_gateway = true

github_repository = "naseeb-helali/mini-write"

postgres_username="miniwrite_admin"

postgres_database="miniwrite_db"