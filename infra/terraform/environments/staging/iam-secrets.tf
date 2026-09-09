resource "aws_iam_role_policy" "ecs_secrets_read" {
  name = "${var.project_name}-${var.environment}-ecs-secrets-read"

  role = module.iam.ecs_task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadApplicationSecrets"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = [
          module.secrets.database_secret_arn,
          module.secrets.redis_secret_arn,
          module.secrets.jwt_secret_arn
        ]
      }
    ]
  })
}