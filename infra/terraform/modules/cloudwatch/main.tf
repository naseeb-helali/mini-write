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

# ==============================================================================
# ECS API - CPU
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_cpu_high" {
  alarm_name = "${local.name_prefix}-api-cpu-high"

  alarm_description = "ECS API CPU utilization is above the configured threshold."

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.api_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ECS API - Memory
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_memory_high" {
  alarm_name = "${local.name_prefix}-api-memory-high"

  alarm_description = "ECS API memory utilization is above the configured threshold."

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.api_memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ECS API - Running Tasks
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_running_tasks_low" {
  alarm_name = "${local.name_prefix}-api-running-tasks-low"

  alarm_description = "ECS API service has no running tasks."

  namespace   = "ECS/ContainerInsights"
  metric_name = "RunningTaskCount"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = 1
  comparison_operator = "LessThanThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.api_service_name
  }

  treat_missing_data = "breaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ECS Worker - CPU
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "worker_cpu_high" {
  alarm_name = "${local.name_prefix}-worker-cpu-high"

  alarm_description = "ECS Worker CPU utilization is above the configured threshold."

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.worker_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.worker_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ECS Worker - Memory
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "worker_memory_high" {
  alarm_name = "${local.name_prefix}-worker-memory-high"

  alarm_description = "ECS Worker memory utilization is above the configured threshold."

  namespace   = "AWS/ECS"
  metric_name = "MemoryUtilization"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.worker_memory_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.worker_service_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ECS Worker - Running Tasks
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "worker_running_tasks_low" {
  alarm_name = "${local.name_prefix}-worker-running-tasks-low"

  alarm_description = "ECS Worker service has no running tasks."

  namespace   = "ECS/ContainerInsights"
  metric_name = "RunningTaskCount"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = 1
  comparison_operator = "LessThanThreshold"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.worker_service_name
  }

  treat_missing_data = "breaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ALB - Load Balancer 5xx
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name = "${local.name_prefix}-alb-5xx"

  alarm_description = "Application Load Balancer is returning elevated 5xx responses."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  statistic = "Sum"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ALB - Target 5xx
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_target_5xx" {
  alarm_name = "${local.name_prefix}-api-target-5xx"

  alarm_description = "ECS API targets are returning elevated 5xx responses."

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_Target_5XX_Count"

  statistic = "Sum"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.target_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ALB - Unhealthy API Targets
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_unhealthy_targets" {
  alarm_name = "${local.name_prefix}-api-unhealthy-targets"

  alarm_description = "One or more ECS API targets are unhealthy."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"

  statistic = "Maximum"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.unhealthy_host_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}

# ==============================================================================
# ALB - Target Response Time
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "api_target_response_time_high" {
  alarm_name = "${local.name_prefix}-api-response-time-high"

  alarm_description = "ECS API target response time is above the configured threshold."

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"

  statistic = "Average"
  period    = var.period_seconds

  evaluation_periods = var.evaluation_periods

  threshold           = var.target_response_time_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.api_target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = var.alarm_actions

  tags = local.common_tags
}