resource "aws_iam_role_policy" "api_s3" {
  name = "${var.project_name}-${var.environment}-api-s3"

  role = module.iam.api_task_role_arn

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
          module.s3.bucket_arns["input"]
        ]
      },
      {
        Sid    = "UploadInputObjects"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${module.s3.bucket_arns["input"]}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "worker_s3" {
  name = "${var.project_name}-${var.environment}-worker-s3"

  role = module.iam.worker_task_role_arn

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
          "${module.s3.bucket_arns["input"]}/*"
        ]
      },
      {
        Sid    = "WriteProcessedObjects"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${module.s3.bucket_arns["processed"]}/*"
        ]
      }
    ]
  })
}