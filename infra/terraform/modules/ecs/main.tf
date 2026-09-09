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

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-cluster"
    }
  )
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name_prefix}/api"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.name_prefix}/worker"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "api" {
  family = "${local.name_prefix}-api"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.api_cpu
  memory = var.api_memory

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.api_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_image
      essential = true

      portMappings = [
        {
          containerPort = var.api_container_port
          hostPort      = var.api_container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.node_env
        },
        {
          name  = "HTTP_PORT"
          value = tostring(var.api_container_port)
        },
        {
          name  = "POSTGRES_HOST"
          value = var.database_host
        },
        {
          name  = "POSTGRES_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "POSTGRES_DB"
          value = var.database_name
        },
        {
          name  = "POSTGRES_USER"
          value = var.database_user
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_host
        },
        {
          name  = "REDIS_PORT"
          value = tostring(var.redis_port)
        },
        {
          name  = "STORAGE_PROVIDER"
          value = "s3"
        },
        {
          name  = "STORAGE_INPUT_BUCKET"
          value = var.input_bucket_name
        },
        {
          name  = "STORAGE_OUTPUT_BUCKET"
          value = var.processed_bucket_name
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      secrets = var.api_secrets

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.api_container_port}/health/ready || exit 1"
        ]

        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "worker" {
  family = "${local.name_prefix}-worker"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = var.worker_cpu
  memory = var.worker_memory

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.worker_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.worker_image
      essential = true

      environment = [
        {
          name  = "NODE_ENV"
          value = var.node_env
        },
        {
          name  = "POSTGRES_HOST"
          value = var.database_host
        },
        {
          name  = "POSTGRES_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "POSTGRES_DB"
          value = var.database_name
        },
        {
          name  = "POSTGRES_USER"
          value = var.database_user
        },
        {
          name  = "REDIS_HOST"
          value = var.redis_host
        },
        {
          name  = "REDIS_PORT"
          value = tostring(var.redis_port)
        },
        {
          name  = "STORAGE_PROVIDER"
          value = "s3"
        },
        {
          name  = "STORAGE_INPUT_BUCKET"
          value = var.input_bucket_name
        },
        {
          name  = "STORAGE_OUTPUT_BUCKET"
          value = var.processed_bucket_name
        },
        {
          name  = "WORKER_CONCURRENCY"
          value = tostring(var.worker_concurrency)
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      secrets = var.worker_secrets

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "worker"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "api" {
  name = "${local.name_prefix}-api"

  cluster = aws_ecs_cluster.this.id

  task_definition = aws_ecs_task_definition.api.arn

  desired_count = var.api_desired_count

  launch_type = "FARGATE"

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = var.api_container_name
    container_port   = var.api_container_port
  }

  network_configuration {
    subnets = var.application_subnet_ids

    security_groups = [
      var.ecs_security_group_id
    ]

    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = local.common_tags
}

resource "aws_ecs_service" "worker" {
  name = "${local.name_prefix}-worker"

  cluster = aws_ecs_cluster.this.id

  task_definition = aws_ecs_task_definition.worker.arn

  desired_count = var.worker_desired_count

  launch_type = "FARGATE"

  network_configuration {
    subnets = var.application_subnet_ids

    security_groups = [
      var.ecs_security_group_id
    ]

    assign_public_ip = false
  }

  tags = local.common_tags
}