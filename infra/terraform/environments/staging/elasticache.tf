module "elasticache" {
  source = "../../modules/elasticache"

  project_name = var.project_name
  environment  = var.environment

  subnet_ids = module.vpc.private_data_subnet_ids

  security_group_ids = [
    module.security_groups.redis_security_group_id
  ]

  node_type      = var.redis_node_type
  engine_version = "7.2"

  port = 6379

  num_cache_nodes = 1

  automatic_failover_enabled = false

  at_rest_encryption_enabled = true

  transit_encryption_enabled = false
}