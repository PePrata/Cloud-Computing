output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID — passed as input to the security, db and messaging modules."
}

output "rds_endpoint" {
  value       = module.db.rds_endpoint
  description = "RDS PostgreSQL endpoint — injected by Terraform into all.yml as db_host for the Spring Boot containers."
}

output "rds_arn" {
  value       = module.db.rds_arn
  description = "Primary RDS instance ARN — consumed by the dr environment (via remote state) as source_db_arn to create the cross-region read replica."
}

output "sqs_order_created_queue_url" {
  value       = module.messaging.order_created_queue_url
  description = "SQS queue URL for order-created events, published by order-service and consumed by product-service."
}

output "sqs_order_status_changed_queue_url" {
  value       = module.messaging.order_status_changed_queue_url
  description = "SQS queue URL for order-status-changed events, published by order-service (no current consumer)."
}

output "ec2_instance_id" {
  value       = module.compute.instance_id
  description = "Primary EC2 instance ID — used by the DR drill workflow to stop/start the host without console access."
}

output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "Primary EC2 Elastic IP — used by deploy.yml to update the Ansible hosts.ini before the playbook runs, and by the dr-controller environment as the Route 53 primary failover target."
}

output "db_username" {
  value       = var.db_username
  description = "Echoed so the dr environment (via remote state) can create a matching SSM parameter; the replica must present the same credentials as the source until promoted."
  sensitive   = true
}

output "db_password" {
  value       = var.db_password
  sensitive   = true
}
