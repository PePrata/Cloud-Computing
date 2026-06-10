output "vpc_id" {
  description = "VPC ID — passed as input to the security, db and messaging modules."
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public subnet IDs — used by the NAT Gateway and ALB."
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private subnet IDs — passed to the messaging module for MSK broker placement."
  value       = aws_subnet.private[*].id
}

output "database_subnets" {
  description = "Data subnet IDs — passed to the db module for RDS isolated placement."
  value       = aws_subnet.database[*].id
}

output "ec2_public_ip" {
  description = "EC2 public IP — used by deploy.yml to update the Ansible hosts.ini before the playbook runs."
  value       = aws_instance.app_host.public_ip
}