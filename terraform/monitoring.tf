locals {
  ecs_dims = ["ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name]
  alb_dims = ["LoadBalancer", aws_lb.main.arn_suffix]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Кількість екземплярів (задач ECS)"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            concat(["ECS/ContainerInsights", "DesiredTaskCount"], local.ecs_dims, [{ label = "Бажана" }]),
            concat(["ECS/ContainerInsights", "RunningTaskCount"], local.ecs_dims, [{ label = "Фактична" }]),
          ]
          yAxis = { left = { min = 0, max = 5 } }
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "CPU, %"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            concat(["AWS/ECS", "CPUUtilization"], local.ecs_dims, [{ label = "Середній CPU" }]),
          ]
          yAxis = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [
              { value = 60, label = "Ціль автомасштабування 60%" },
              { value = 70, label = "Поріг сповіщення 70%", color = "#d62728" },
            ]
          }
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title   = "Запити за хвилину"
          region  = var.region
          view    = "timeSeries"
          stat    = "Sum"
          period  = 60
          metrics = [concat(["AWS/ApplicationELB", "RequestCount"], local.alb_dims, [{ label = "Запити" }])]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title   = "Латентність p95, с"
          region  = var.region
          view    = "timeSeries"
          stat    = "p95"
          period  = 60
          metrics = [concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_dims, [{ label = "p95" }])]
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "Помилки 5xx"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 60
          metrics = [
            concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.alb_dims, [{ label = "5xx від застосунку" }]),
            concat(["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count"], local.alb_dims, [{ label = "5xx від балансувальника" }]),
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "База даних: CPU, %"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.identifier, { label = "CPU RDS" }],
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Кеш: частка влучань, %"
          region = var.region
          view   = "timeSeries"
          stat   = "Average"
          period = 60
          metrics = [
            ["AWS/ElastiCache", "CacheHitRate", "CacheClusterId", aws_elasticache_cluster.redis.cluster_id, "CacheNodeId", "0001", { label = "Hit rate" }],
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "${var.project}-cpu-high"
  alarm_description = "Середнє завантаження CPU сервісу понад 70% протягом 2 хвилин"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  statistic = "Average"

  comparison_operator = "GreaterThanThreshold"
  threshold           = 70
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
