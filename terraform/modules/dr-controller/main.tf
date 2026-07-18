# ── ROUTE 53 HEALTH CHECKS ────────────────────────────────────
# Route 53 health check metrics only exist in us-east-1 regardless of
# which region is checked, so this module (and its provider) must run
# with the us-east-1 alias when called from environments in other
# regions. Both checks hit the same app-gateway health endpoint that
# docker-compose already exposes.
resource "aws_route53_health_check" "primary" {
  ip_address        = var.primary_endpoint
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = 10
  failure_threshold = 2
  tags              = merge(var.tags, { Name = "${var.project_name}-primary-health" })
}

resource "aws_route53_health_check" "standby" {
  ip_address        = var.standby_endpoint
  port              = var.health_check_port
  type              = "HTTP"
  resource_path     = var.health_check_path
  request_interval  = 10
  failure_threshold = 2
  tags              = merge(var.tags, { Name = "${var.project_name}-standby-health" })
}

# ── CLIENT-FACING ROUTING: OUT OF SCOPE HERE ──────────────────
# This build does not own/delegate a public domain (see
# docs/limitations.md), so it cannot create Route 53 failover A
# records (aws_route53_record requires an existing hosted zone).
# What IS fully automated below is the backend half of failover:
# detecting the primary is down and promoting the standby database
# with zero console interaction. In a deployment with a real domain,
# the two aws_route53_health_check resources above are exactly what
# a PRIMARY/SECONDARY failover_routing_policy record pair would key
# off — adding DNS routing back is additive, not a redesign.

# ── ALARM + SNS: TRIGGERS THE AUTOMATED PROMOTION ────────────
# Watches the same health check data Route 53 DNS failover would use,
# so the promotion trigger is health-check-driven either way.
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
