output "api_cpu_alarm_arn" {
  description = "ARN of the API CPU alarm"
  value       = aws_cloudwatch_metric_alarm.api_cpu_high.arn
}

output "api_memory_alarm_arn" {
  description = "ARN of the API memory alarm"
  value       = aws_cloudwatch_metric_alarm.api_memory_high.arn
}

output "api_running_tasks_alarm_arn" {
  description = "ARN of the API running task alarm"
  value       = aws_cloudwatch_metric_alarm.api_running_tasks_low.arn
}

output "worker_cpu_alarm_arn" {
  description = "ARN of the Worker CPU alarm"
  value       = aws_cloudwatch_metric_alarm.worker_cpu_high.arn
}

output "worker_memory_alarm_arn" {
  description = "ARN of the Worker memory alarm"
  value       = aws_cloudwatch_metric_alarm.worker_memory_high.arn
}

output "worker_running_tasks_alarm_arn" {
  description = "ARN of the Worker running task alarm"
  value       = aws_cloudwatch_metric_alarm.worker_running_tasks_low.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx alarm"
  value       = aws_cloudwatch_metric_alarm.alb_5xx.arn
}

output "api_target_5xx_alarm_arn" {
  description = "ARN of the API target 5xx alarm"
  value       = aws_cloudwatch_metric_alarm.api_target_5xx.arn
}

output "api_unhealthy_targets_alarm_arn" {
  description = "ARN of the API unhealthy targets alarm"
  value       = aws_cloudwatch_metric_alarm.api_unhealthy_targets.arn
}

output "api_response_time_alarm_arn" {
  description = "ARN of the API response time alarm"
  value       = aws_cloudwatch_metric_alarm.api_target_response_time_high.arn
}