output "bootstrap_brokers" {
  description = "A string collection array outlining plaintext Kafka brokers endpoint strings used by Spring Boot dependencies."
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}
