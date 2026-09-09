locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

resource "aws_elasticache_subnet_group" "this" {
  name = "${var.project_name}-${var.environment}-redis"

  subnet_ids = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-subnet-group"
    }
  )
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"

  description = "Mini-Write Redis-compatible cache and queue"

  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = var.node_type

  port = var.port

  num_cache_clusters = var.num_cache_nodes

  automatic_failover_enabled = var.automatic_failover_enabled

  multi_az_enabled = var.automatic_failover_enabled

  subnet_group_name = aws_elasticache_subnet_group.this.name

  security_group_ids = var.security_group_ids

  at_rest_encryption_enabled = var.at_rest_encryption_enabled

  transit_encryption_enabled = var.transit_encryption_enabled

  auto_minor_version_upgrade = true

  apply_immediately = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis"
    }
  )
}