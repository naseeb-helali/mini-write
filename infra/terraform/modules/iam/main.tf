data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role = aws_iam_role.ecs_task_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-task-role"
    }
  )
}

resource "aws_iam_role" "api_task" {
  name = "${local.name_prefix}-api-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-api-task-role"
    }
  )
}

resource "aws_iam_role" "worker_task" {
  name = "${local.name_prefix}-worker-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-worker-task-role"
    }
  )
}

data "aws_iam_policy_document" "ecs_task_secrets" {
  statement {
    sid    = "ReadApplicationSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  role   = aws_iam_role.ecs_task_execution.name
  policy = data.aws_iam_policy_document.ecs_task_secrets.json
}


resource "aws_iam_role_policy" "api_s3" {
  name = "${var.project_name}-${var.environment}-api-s3"

  role = aws_iam_role.api_task.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListInputBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          var.input_bucket_arn
        ]
      },
      {
        Sid    = "UploadInputObjects"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${var.input_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_s3" {
  name = "${var.project_name}-${var.environment}-worker-s3"

  role = aws_iam_role.worker_task.name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadInputObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${var.input_bucket_arn}/*"
        ]
      },
      {
        Sid    = "WriteProcessedObjects"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${var.processed_bucket_arn}/*"
        ]
      }
    ]
  })
}