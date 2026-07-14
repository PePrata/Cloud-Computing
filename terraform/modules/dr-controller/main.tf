# ── ROUTE 53 HEALTH CHECKS ────────────────────────────────────
# Route 53 health check metrics only exist in us-east-1 regardless of
# which region is checked, so this module (and its provider) must run
# with the us-east-1 alias when called from environments in other
# regions. Both checks hit the same app-gateway health endpoint that
# docker-compose already exposes.
resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_endpoint
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = 10
  failure_threshold = 2
  tags              = merge(var.tags, { Name = "${var.project_name}-primary-health" })
}

resource "aws_route53_health_check" "standby" {
  fqdn              = var.standby_endpoint
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = 10
  failure_threshold = 2
  tags              = merge(var.tags, { Name = "${var.project_name}-standby-health" })
}

# ── FAILOVER DNS RECORDS ──────────────────────────────────────
# A single failover-routed record set. Clients always resolve
# app.<zone> and get the primary's IP while it's healthy; Route 53
# switches to the standby's IP automatically once the primary health
# check fails, with no controller/Lambda involvement.
resource "aws_route53_record" "primary" {
  zone_id = var.hosted_zone_id
  name    = var.dns_name
  type    = "A"
  ttl     = 30
  records = [var.primary_ip]

  failover_routing_policy {
    type = "PRIMARY"
  }
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "standby" {
  zone_id = var.hosted_zone_id
  name    = var.dns_name
  type    = "A"
  ttl     = 30
  records = [var.standby_ip]

  failover_routing_policy {
    type = "SECONDARY"
  }
  set_identifier  = "standby"
  health_check_id = aws_route53_health_check.standby.id
}

# ── ALARM + SNS: TRIGGERS THE ONE STEP DNS CAN'T DO ──────────
# Route 53 already re-routes traffic on its own; this alarm exists
# purely to trigger the RDS replica promotion, since a standby serving
# traffic against a read-only replica would fail every write.
resource "aws_sns_topic" "failover" {
  name = "${var.project_name}-dr-failover"
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "primary_unhealthy" {
  alarm_name          = "${var.project_name}-primary-unhealthy"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.primary.id }
  statistic           = "Minimum"
  # 1 evaluation period keeps end-to-end detection close to the Route 53
  # health check's own ~20-30s detection window for the failover drill.
  # A production deployment carrying real traffic would want 2-3 periods
  # here to tolerate transient blips without flapping into a promotion.
  period              = 60
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.failover.arn]
  tags                = var.tags
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.failover.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.promote_replica.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.promote_replica.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.failover.arn
}

# ── LAMBDA: PROMOTES THE STANDBY REPLICA ─────────────────────
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-dr-promote-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-dr-promote-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["rds:PromoteReadReplica", "rds:DescribeDBInstances"]
        Resource = var.standby_replica_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = var.status_parameter_arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "promote_replica" {
  function_name    = "${var.project_name}-dr-promote-replica"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      DR_REGION            = var.standby_region
      REPLICA_INSTANCE_ID  = var.standby_replica_id
      STATUS_PARAMETER_NAME = var.status_parameter_name
    }
  }

  tags = var.tags
}
