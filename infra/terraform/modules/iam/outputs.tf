output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS application task role."
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS application task role."
  value       = aws_iam_role.ecs_task.name
}

output "api_task_role_arn" {
  description = "ARN of the ECS API task role."

  value = aws_iam_role.api_task.arn
}

output "api_task_role_name" {
  description = "ARN of the ECS API task role."

  value = aws_iam_role.api_task.id
}

output "worker_task_role_arn" {
  description = "ARN of the ECS Worker task role."

  value = aws_iam_role.worker_task.arn
}

output "worker_task_role_name" {
  description = "ARN of the ECS Worker task role."

  value = aws_iam_role.worker_task.id
}