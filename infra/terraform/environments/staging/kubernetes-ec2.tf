module "kubernetes_ec2" {
  source = "../../modules/kubernetes-ec2"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_app_subnet_ids = module.vpc.private_app_subnet_ids

  ecr_repository_arns = values(module.ecr.repository_arns)

  input_bucket_arn     = module.s3.bucket_arns["input"]
  processed_bucket_arn = module.s3.bucket_arns["processed"]

  secrets_manager_arns = [
    module.secrets.database_secret_arn,
    module.secrets.redis_secret_arn,
    module.secrets.jwt_secret_arn
  ]

  ubuntu_ami_id            = var.k8s_ubuntu_ami_id
  ubuntu_ami_ssm_parameter = var.k8s_ubuntu_ami_ssm_parameter

  control_plane_instance_type = var.k8s_control_plane_instance_type
  worker_instance_type        = var.k8s_worker_instance_type

  control_plane_root_volume_size = var.k8s_control_plane_root_volume_size
  worker_root_volume_size        = var.k8s_worker_root_volume_size

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Platform    = "kubernetes"
  }
}
