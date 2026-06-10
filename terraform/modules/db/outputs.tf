output "rds_endpoint" {
  description = "The connection string host endpoint allocated for the target PostgreSQL cluster engine instance."
  value       = aws_db_instance.postgres.endpoint
}
