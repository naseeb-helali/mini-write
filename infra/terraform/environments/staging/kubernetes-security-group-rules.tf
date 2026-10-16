resource "aws_security_group" "kubernetes_rds_access" {
  name        = "${var.project_name}-${var.environment}-k8s-rds-access"
  description = "Additional RDS access for Mini-Write Kubernetes nodes."
  vpc_id      = module.vpc.vpc_id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "kubernetes-data-access"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_kubernetes_nodes" {
  security_group_id            = aws_security_group.kubernetes_rds_access.id
  referenced_security_group_id = module.kubernetes_ec2.node_security_group_id

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  description = "Allow PostgreSQL access from Mini-Write Kubernetes nodes."
}

resource "aws_security_group" "kubernetes_redis_access" {
  name        = "${var.project_name}-${var.environment}-k8s-redis-access"
  description = "Additional Redis access for Mini-Write Kubernetes nodes."
  vpc_id      = module.vpc.vpc_id

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "kubernetes-data-access"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_kubernetes_nodes" {
  security_group_id            = aws_security_group.kubernetes_redis_access.id
  referenced_security_group_id = module.kubernetes_ec2.node_security_group_id

  ip_protocol = "tcp"
  from_port   = 6379
  to_port     = 6379

  description = "Allow Redis access from Mini-Write Kubernetes nodes."
}
