resource "aws_sqs_queue" "order_created" {
  name                       = "order-created"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 dias, igual ao default do Kafka log.retention

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-order-created" })
}

resource "aws_sqs_queue" "order_status_changed" {
  name                       = "order-status-changed"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-order-status-changed" })
}
