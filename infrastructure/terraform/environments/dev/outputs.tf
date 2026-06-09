output "vpc_id" {
  value = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "The hostname endpoint for the shared PostgreSQL cluster"
  value       = module.db.rds_endpoint
}

output "kafka_bootstrap_brokers" {
  description = "Connection string array used by Spring Boot properties for Kafka bootstrap connection"
  value       = module.messaging.bootstrap_brokers
}
