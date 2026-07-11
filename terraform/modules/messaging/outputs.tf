output "order_created_queue_arn" {
  description = "ARN of the order-created queue — used to scope the app host's IAM policy."
  value       = aws_sqs_queue.order_created.arn
}

output "order_status_changed_queue_arn" {
  description = "ARN of the order-status-changed queue — used to scope the app host's IAM policy."
  value       = aws_sqs_queue.order_status_changed.arn
}

output "order_created_queue_url" {
  description = "URL of the order-created queue."
  value       = aws_sqs_queue.order_created.url
}

output "order_status_changed_queue_url" {
  description = "URL of the order-status-changed queue."
  value       = aws_sqs_queue.order_status_changed.url
}
