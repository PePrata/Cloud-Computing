# Substitui o cluster MSK original por duas filas SQS "standard".
# Motivo: MSK exige subscrição/serviço não disponível em contas AWS Free
# Tier; SQS é serverless, sem cluster para provisionar, e cobre o mesmo
# caso de uso (order-service publica, product-service consome) porque
# há sempre exatamente um consumidor por evento — não é preciso o
# fan-out de vários consumer groups que só o Kafka oferece.

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
