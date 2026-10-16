data "aws_caller_identity" "kubernetes" {}

data "aws_partition" "kubernetes" {}

data "aws_iam_policy_document" "kubernetes_github_assume_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.github_oidc.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:staging"]
    }
  }
}

resource "aws_s3_bucket" "kubernetes_ansible_transfer" {
  bucket = "${var.project_name}-${var.environment}-k8s-ansible-${data.aws_caller_identity.kubernetes.account_id}-${var.aws_region}"

  force_destroy = false

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "kubernetes-ansible-transfer"
  }
}

resource "aws_s3_bucket_public_access_block" "kubernetes_ansible_transfer" {
  bucket = aws_s3_bucket.kubernetes_ansible_transfer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kubernetes_ansible_transfer" {
  bucket = aws_s3_bucket.kubernetes_ansible_transfer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "kubernetes_ansible_transfer" {
  bucket = aws_s3_bucket.kubernetes_ansible_transfer.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "kubernetes_ansible_transfer" {
  bucket = aws_s3_bucket.kubernetes_ansible_transfer.id

  rule {
    id     = "expire-ansible-transfer-files"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.kubernetes_ansible_transfer,
    aws_s3_bucket_ownership_controls.kubernetes_ansible_transfer
  ]
}

resource "aws_iam_role" "kubernetes_bootstrap" {
  name                 = "${var.project_name}-${var.environment}-k8s-bootstrap"
  assume_role_policy   = data.aws_iam_policy_document.kubernetes_github_assume_role.json
  max_session_duration = 3600

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "kubernetes-bootstrap"
  }
}

data "aws_iam_policy_document" "kubernetes_bootstrap" {
  statement {
    sid    = "DescribeManagedNodes"
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ssm:DescribeInstanceInformation",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "StartSessionsOnProjectNodes"
    effect = "Allow"

    actions = [
      "ssm:StartSession"
    ]

    resources = concat(
      module.kubernetes_ec2.node_instance_arns,
      [
        "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}::document/SSM-SessionManagerRunShell",
        "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}::document/AWS-StartSSHSession",
        "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}::document/AWS-StartInteractiveCommand"
      ]
    )
  }

  statement {
    sid    = "ManageOwnSessions"
    effect = "Allow"

    actions = [
      "ssm:ResumeSession",
      "ssm:TerminateSession"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.kubernetes.account_id}:session/$${aws:userid}-*"
    ]
  }

  statement {
    sid    = "UseAnsibleTransferBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [aws_s3_bucket.kubernetes_ansible_transfer.arn]
  }

  statement {
    sid    = "TransferAnsibleFiles"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = ["${aws_s3_bucket.kubernetes_ansible_transfer.arn}/*"]
  }
}

resource "aws_iam_role_policy" "kubernetes_bootstrap" {
  name   = "kubernetes-bootstrap-access"
  role   = aws_iam_role.kubernetes_bootstrap.id
  policy = data.aws_iam_policy_document.kubernetes_bootstrap.json
}

resource "aws_iam_role" "kubernetes_cd" {
  name                 = "${var.project_name}-${var.environment}-k8s-cd"
  assume_role_policy   = data.aws_iam_policy_document.kubernetes_github_assume_role.json
  max_session_duration = 3600

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "kubernetes-cd"
  }
}

data "aws_iam_policy_document" "kubernetes_cd" {
  statement {
    sid    = "SendDeploymentCommandToControlPlane"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript"
    ]
  }

  statement {
    sid    = "TargetOnlyTheKubernetesControlPlane"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      module.kubernetes_ec2.control_plane_instance_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid    = "ReadCommandExecutionResults"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
      "ssm:DescribeInstanceInformation",
      "ssm:DescribeDocument"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CancelDeploymentCommands"
    effect = "Allow"

    actions = [
      "ssm:CancelCommand"
    ]

    resources = [
      "arn:${data.aws_partition.kubernetes.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.kubernetes.account_id}:*"
    ]
  }
}

resource "aws_iam_role_policy" "kubernetes_cd" {
  name   = "kubernetes-cd-access"
  role   = aws_iam_role.kubernetes_cd.id
  policy = data.aws_iam_policy_document.kubernetes_cd.json
}
