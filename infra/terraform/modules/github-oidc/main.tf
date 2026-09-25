locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

data "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket_name
}

data "aws_iam_policy_document" "tfstate_access" {
  statement {
    sid    = "S3StateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      data.aws_s3_bucket.tfstate.arn
    ]
  }

  statement {
    sid    = "S3StateObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${data.aws_s3_bucket.tfstate.arn}/*"
    ]
  }
}


data "aws_partition" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-actions-oidc"
    }
  )
}

data "aws_iam_policy_document" "iac_plan_assume_role" {
  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = var.plan_subjects
    }
  }
}

resource "aws_iam_role" "iac_plan" {
  name = "${var.project}-github-iac-plan"

  assume_role_policy = data.aws_iam_policy_document.iac_plan_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-iac-plan"
    }
  )
}

data "aws_iam_policy_document" "iac_apply_assume_role" {
  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        var.apply_subject
      ]
    }
  }
}

resource "aws_iam_role" "iac_apply" {
  name = "${var.project}-github-iac-apply"

  assume_role_policy = data.aws_iam_policy_document.iac_apply_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-iac-apply"
    }
  )
}

resource "aws_iam_role_policy" "iac_plan_tfstate" {
  name   = "${var.project}-iac-plan-tfstate-policy"
  role   = aws_iam_role.iac_plan.name
  policy = data.aws_iam_policy_document.tfstate_access.json
}

resource "aws_iam_role_policy" "iac_apply_tfstate" {
  name   = "${var.project}-iac-apply-tfstate-policy"
  role   = aws_iam_role.iac_apply.name
  policy = data.aws_iam_policy_document.tfstate_access.json
}




# ==========================================
# Managed Policy Attachments for iac_plan
# ==========================================

# 1. EC2 & VPC Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_ec2_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# 2. RDS Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_rds_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"
}

# 3. S3 Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_s3_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 4. ECR Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_ecr_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 5. CloudWatch Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_cloudwatch_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# 6. IAM Read-Only Access
resource "aws_iam_role_policy_attachment" "iac_plan_iam_readonly" {
  role       = aws_iam_role.iac_plan.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

# ==========================================
# Custom Policy for Missing Reads & Tagging
# ==========================================
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "iac_plan_additional_reads" {
  # 1. ElastiCache Read & Tagging
  statement {
    sid    = "ElastiCacheReadAndTags"
    effect = "Allow"
    actions = [
      "elasticache:Describe*",
      "elasticache:ListTagsForResource"
    ]
    resources = ["*"]
  }

  # 2. ECS Read & Tagging
  statement {
    sid    = "ECSReadOnly"
    effect = "Allow"
    actions = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:ListTagsForResource"
    ]
    resources = ["*"]
  }

  # 3. Secrets Manager Read
  statement {
    sid    = "SecretsManagerReadOnly"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}-${var.environment}/*"
    ]
  }

  # 4. General Resource Tagging Read
  statement {
    sid    = "ResourceTaggingReadOnly"
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iac_plan_additional_reads" {
  name   = "${var.project}-iac-plan-additional-reads-policy"
  role   = aws_iam_role.iac_plan.name
  policy = data.aws_iam_policy_document.iac_plan_additional_reads.json
}

# ==========================================
# CI Runner Role
# ==========================================

data "aws_iam_policy_document" "ci_runner_assume_role" {
  count = length(var.ci_subjects) > 0 ? 1 : 0

  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.ci_subjects
    }
  }
}

resource "aws_iam_role" "ci_runner" {
  count = length(var.ci_subjects) > 0 ? 1 : 0

  name = "${var.project}-github-ci-runner"

  assume_role_policy = data.aws_iam_policy_document.ci_runner_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-ci-runner"
    }
  )
}

data "aws_iam_policy_document" "ci_ecr_policy" {
  count = length(var.ci_subjects) > 0 ? 1 : 0

  # ==========================================================
  # ECR Authentication
  # ==========================================================
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  # ==========================================================
  # ECR Push
  # ==========================================================
  statement {
    sid    = "ECRPush"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage"
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}-api",
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}-worker"
    ]
  }
}

resource "aws_iam_role_policy" "ci_ecr" {
  count = length(var.ci_subjects) > 0 ? 1 : 0

  name   = "${var.project}-ci-ecr-policy"
  role   = aws_iam_role.ci_runner[0].name
  policy = data.aws_iam_policy_document.ci_ecr_policy[0].json
}

# ==========================================
# CD Runner Role
# ==========================================

data "aws_iam_policy_document" "cd_runner_assume_role" {
  count = length(var.cd_subjects) > 0 ? 1 : 0

  statement {
    sid    = "GitHubActionsOIDC"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.cd_subjects
    }
  }
}

resource "aws_iam_role" "cd_runner" {
  count = length(var.cd_subjects) > 0 ? 1 : 0

  name = "${var.project}-github-cd-runner"

  assume_role_policy = data.aws_iam_policy_document.cd_runner_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-github-cd-runner"
    }
  )
}

data "aws_iam_policy_document" "cd_runner_policy" {
  count = length(var.cd_subjects) > 0 ? 1 : 0

  # ==========================================================
  # ECR Access
  # ==========================================================
  statement {
    sid    = "ECRAuth"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:ListImages"
    ]

    resources = ["*"]
  }

  # ==========================================================
  # ECS Access
  # ==========================================================
  statement {
    sid    = "ECSAccess"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project}*",
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.project}*",
      "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.project}*"
    ]
  }

  # ==========================================================
  # Pass only the ECS task roles used by staging
  # ==========================================================
  statement {
    sid    = "PassECSTaskRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-ecs-task-execution-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-api-task-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-worker-task-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  # ==========================================================
  # CloudWatch Logs
  # ==========================================================
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/${local.name_prefix}*:*"
    ]
  }
}

resource "aws_iam_role_policy" "cd_runner_policy" {
  count = length(var.cd_subjects) > 0 ? 1 : 0

  name   = "${var.project}-cd-runner-policy"
  role   = aws_iam_role.cd_runner[0].name
  policy = data.aws_iam_policy_document.cd_runner_policy[0].json
}