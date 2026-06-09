output "vpc_id" {
  description = "The system-wide infrastructure wrapper identification string."
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of public subnet identifiers assigned for hosting public load balancing devices."
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of private subnet identifiers allocated for hosting compute microservice instances."
  value       = aws_subnet.private[*].id
}

output "database_subnets" {
  description = "List of protected data subnet configurations allocated for transactional engines."
  value       = aws_subnet.database[*].id
}
