output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID — passed as input to the security, db and messaging modules."
}

output "rds_endpoint" {
  value       = module.db.rds_endpoint
  description = "RDS PostgreSQL endpoint — injected by Terraform into all.yml as db_host for the Spring Boot containers."
}

output "sqs_order_created_queue_url" {
  value       = module.messaging.order_created_queue_url
  description = "SQS queue URL for order-created events, published by order-service and consumed by product-service."
}

output "sqs_order_status_changed_queue_url" {
  value       = module.messaging.order_status_changed_queue_url
  description = "SQS queue URL for order-status-changed events, published by order-service (no current consumer)."
}

output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "EC2 public IP — used by deploy.yml to update the Ansible hosts.ini before the playbook runs."
}