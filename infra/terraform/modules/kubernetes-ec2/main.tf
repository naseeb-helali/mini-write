data "aws_partition" "current" {}

data "aws_ssm_parameter" "ubuntu_2404_amd64" {
  count = var.ubuntu_ami_id == null ? 1 : 0
  name  = var.ubuntu_ami_ssm_parameter
}

locals {
  name_prefix = "${var.project_name}-${var.environment}-k8s"
  ami_id      = var.ubuntu_ami_id != null ? var.ubuntu_ami_id : data.aws_ssm_parameter.ubuntu_2404_amd64[0].value

  nodes = {
    control_plane = {
      name             = "${local.name_prefix}-control-plane"
      subnet_id        = var.private_app_subnet_ids[0]
      instance_type    = var.control_plane_instance_type
      root_volume_size = var.control_plane_root_volume_size
      kubernetes_role  = "control-plane"
    }
    worker_01 = {
      name             = "${local.name_prefix}-worker-01"
      subnet_id        = var.private_app_subnet_ids[0]
      instance_type    = var.worker_instance_type
      root_volume_size = var.worker_root_volume_size
      kubernetes_role  = "worker"
    }
    worker_02 = {
      name             = "${local.name_prefix}-worker-02"
      subnet_id        = var.private_app_subnet_ids[1]
      instance_type    = var.worker_instance_type
      root_volume_size = var.worker_root_volume_size
      kubernetes_role  = "worker"
    }
  }
}

resource "aws_iam_role" "kubernetes_nodes" {
  name = "${local.name_prefix}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-node-role"
    Component = "kubernetes-node-identity"
  })
}

resource "aws_iam_instance_profile" "kubernetes_nodes" {
  name = "${local.name_prefix}-node-profile"
  role = aws_iam_role.kubernetes_nodes.name

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-node-profile"
    Component = "kubernetes-node-identity"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.kubernetes_nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.kubernetes_nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "kubernetes_node_permissions" {
  statement {
    sid    = "ECRAuthorizationToken"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PullMiniWriteImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = var.ecr_repository_arns
  }

  statement {
    sid    = "ReadMiniWriteRuntimeSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]

    resources = var.secrets_manager_arns
  }

  statement {
    sid    = "ListMiniWriteObjectBuckets"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      var.input_bucket_arn,
      var.processed_bucket_arn
    ]
  }

  statement {
    sid    = "MiniWriteApplicationObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${var.input_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "MiniWriteApplicationObjectWrites"
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${var.input_bucket_arn}/*",
      "${var.processed_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "kubernetes_node_permissions" {
  name   = "kubernetes-node-runtime"
  role   = aws_iam_role.kubernetes_nodes.id
  policy = data.aws_iam_policy_document.kubernetes_node_permissions.json
}


resource "aws_security_group" "kubernetes_nodes" {
  name        = "${local.name_prefix}-nodes"
  description = "Kubernetes node-to-node and cluster traffic for Mini-Write."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-nodes"
    Component = "kubernetes-networking"
  })

}

resource "aws_vpc_security_group_egress_rule" "kubernetes_nodes_outbound" {
  security_group_id = aws_security_group.kubernetes_nodes.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Outbound access through the existing NAT Gateway."
}

resource "aws_security_group" "kubernetes_alb" {
  name        = "${local.name_prefix}-alb"
  description = "Public HTTP entry point for the Mini-Write Kubernetes Gateway."
  vpc_id      = var.vpc_id

  ingress {
    description = "Initial public HTTP entry point."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Forward traffic and health checks to worker NodePort."
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.kubernetes_nodes.id]
  }

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-alb"
    Component = "kubernetes-networking"
  })
}

resource "aws_vpc_security_group_ingress_rule" "node_api_server" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
  description                  = "Kubernetes API server traffic between cluster nodes."
}

resource "aws_vpc_security_group_ingress_rule" "node_kubelet" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Kubelet API traffic between cluster nodes."
}

resource "aws_vpc_security_group_ingress_rule" "node_calico_vxlan" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  ip_protocol                  = "udp"
  from_port                    = 4789
  to_port                      = 4789
  description                  = "Calico VXLAN overlay traffic between cluster nodes."
}

resource "aws_vpc_security_group_ingress_rule" "node_calico_typha" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  referenced_security_group_id = aws_security_group.kubernetes_nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 5473
  to_port                      = 5473
  description                  = "Calico Typha synchronization traffic between cluster nodes."
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodeport_from_alb" {
  security_group_id            = aws_security_group.kubernetes_nodes.id
  referenced_security_group_id = aws_security_group.kubernetes_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 30080
  to_port                      = 30080
  description                  = "Kubernetes ALB traffic to the NGINX Gateway NodePort."
}

resource "aws_instance" "kubernetes_nodes" {
  for_each = local.nodes

  ami                         = local.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [aws_security_group.kubernetes_nodes.id]
  iam_instance_profile        = aws_iam_instance_profile.kubernetes_nodes.name
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/templates/ensure-ssm-agent.sh.tftpl", {
    node_name = each.value.name
  })

  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = merge(var.tags, {
      Name      = "${each.value.name}-root"
      NodeRole  = each.value.kubernetes_role
      Component = "kubernetes-node-storage"
    })
  }

  tags = merge(var.tags, {
    Name           = each.value.name
    KubernetesRole = each.value.kubernetes_role
    KubernetesNode = each.key
    Component      = "kubernetes-compute"
    SSMManaged     = "true"
  })

  depends_on = [
    aws_iam_role_policy.kubernetes_node_permissions,
    aws_iam_role_policy_attachment.ssm_managed_instance_core,
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

resource "aws_lb" "kubernetes" {
  name               = substr(replace("${local.name_prefix}-alb", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kubernetes_alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-alb"
    Component = "kubernetes-entry"
  })
}

resource "aws_lb_target_group" "kubernetes_workers" {
  name        = substr(replace("${local.name_prefix}-workers", "/[^a-zA-Z0-9-]/", ""), 0, 32)
  port        = 30080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health/live"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-workers"
    Component = "kubernetes-entry"
  })
}

resource "aws_lb_target_group_attachment" "worker_nodes" {
  for_each = {
    worker_01 = aws_instance.kubernetes_nodes["worker_01"].id
    worker_02 = aws_instance.kubernetes_nodes["worker_02"].id
  }

  target_group_arn = aws_lb_target_group.kubernetes_workers.arn
  target_id        = each.value
  port             = 30080
}

resource "aws_lb_listener" "kubernetes_http" {
  load_balancer_arn = aws_lb.kubernetes.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kubernetes_workers.arn
  }
}

