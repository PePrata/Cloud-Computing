output "sns_topic_arn" {
  value       = aws_sns_topic.failover.arn
  description = "SNS topic that fans out the primary-unhealthy alarm to the promotion Lambda. Also usable to manually publish a test notification during a drill."
}

output "primary_health_check_id" {
  value = aws_route53_health_check.primary.id
}

output "standby_health_check_id" {
  value = aws_route53_health_check.standby.id
}

output "promote_lambda_name" {
  value = aws_lambda_function.promote_replica.function_name
}
