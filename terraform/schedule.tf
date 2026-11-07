resource "aws_appautoscaling_scheduled_action" "day" {
  count = var.enable_schedule ? 1 : 0

  name               = "${var.project}-day"
  service_namespace  = aws_appautoscaling_target.app.service_namespace
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  schedule           = "cron(0 8 * * ? *)"
  timezone           = "Europe/Kiev"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 4
  }
}

resource "aws_appautoscaling_scheduled_action" "night" {
  count = var.enable_schedule ? 1 : 0

  name               = "${var.project}-night"
  service_namespace  = aws_appautoscaling_target.app.service_namespace
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  schedule           = "cron(0 22 * * ? *)"
  timezone           = "Europe/Kiev"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 4
  }
}
