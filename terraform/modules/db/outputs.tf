output "rds_endpoint" {
  description = "The connection string host endpoint allocated for this instance (primary or replica)."
  value       = var.is_replica ? aws_db_instance.replica[0].endpoint : aws_db_instance.postgres[0].endpoint
}

output "rds_arn" {
  description = "ARN of this DB instance. In the primary region, referenced by the DR environment (source_db_arn) to build the cross-region replica, and by the dr-controller module (rds:PromoteReadReplica target is the replica's own ARN, obtained from the DR environment instead)."
  value       = var.is_replica ? aws_db_instance.replica[0].arn : aws_db_instance.postgres[0].arn
}

output "rds_id" {
  description = "The RDS instance identifier (DB instance ID), used by the DR controller Lambda to call rds:PromoteReadReplica and rds:DescribeDBInstances."
  value       = var.is_replica ? aws_db_instance.replica[0].id : aws_db_instance.postgres[0].id
}

output "is_replica" {
  description = "Echoes var.is_replica so callers can branch without re-declaring the flag."
  value       = var.is_replica
}
