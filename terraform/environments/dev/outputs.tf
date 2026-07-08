output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID — passed as input to the security, db and messaging modules."
}

output "rds_endpoint" {
  value       = module.db.rds_endpoint
  description = "RDS PostgreSQL endpoint — injected by Terraform into all.yml as db_host for the Spring Boot containers."
}

output "msk_bootstrap_brokers" {
  value       = module.messaging.bootstrap_brokers
  description = "MSK Kafka bootstrap brokers (port 9092) — injected into all.yml as kafka_brokers for SPRING_KAFKA_BOOTSTRAP_SERVERS."
}

output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "EC2 public IP — used by deploy.yml to update the Ansible hosts.ini before the playbook runs."
}
