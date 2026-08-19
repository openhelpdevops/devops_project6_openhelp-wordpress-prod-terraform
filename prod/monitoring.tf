resource "aws_cloudwatch_log_group" "apache_access" {
  name              = "/${var.project_name}/${var.environment}/wordpress/apache-access"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "apache_error" {
  name              = "/${var.project_name}/${var.environment}/wordpress/apache-error"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "cloud_init" {
  name              = "/${var.project_name}/${var.environment}/wordpress/cloud-init"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}-${var.environment}-wordpress"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "wordpress" {
  resource_arn            = aws_wafv2_web_acl.wordpress.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx"
  alarm_description   = "ALB is returning HTTP 5xx responses"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.wordpress.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts"
  alarm_description   = "One or more WordPress targets are unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.wordpress.arn_suffix
    TargetGroup  = aws_lb_target_group.wordpress.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-high-cpu"
  alarm_description   = "RDS CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.wordpress.identifier
  }
}
