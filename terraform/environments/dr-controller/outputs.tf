output "failover_dns_name" {
  value = module.dr_controller.failover_dns_name
}

output "sns_topic_arn" {
  value       = module.dr_controller.sns_topic_arn
  description = "Publish a test message here to manually trigger the promotion Lambda during a drill, without waiting for the health check/alarm."
}

output "promote_lambda_name" {
  value = module.dr_controller.promote_lambda_name
}
