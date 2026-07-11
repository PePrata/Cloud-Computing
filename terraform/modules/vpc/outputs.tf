output "vpc_id" {
  description = "VPC ID — passed as input to the security, db and messaging modules."
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public subnet IDs — used by the NAT Gateway and ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private subnet IDs — reserved for future use by internal services that need to stay off the public internet."
  value       = aws_subnet.private[*].id
}

output "database_subnets" {
  description = "Data subnet IDs — passed to the db module for RDS isolated placement."
  value       = aws_subnet.database[*].id
}
