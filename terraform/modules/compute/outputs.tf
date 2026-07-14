output "public_ip" {
  description = "App host stable public IP (Elastic IP) — used to populate the Ansible hosts.ini before the playbook runs, and as the Route 53 failover target."
  value       = aws_eip.app_host.public_ip
}

output "instance_id" {
  description = "App host EC2 instance ID."
  value       = aws_instance.app_host.id
}

output "app_host_role_arn" {
  description = "IAM role ARN of the app host — referenced by the secrets module to grant SSM read access without a circular module dependency."
  value       = aws_iam_role.app_host.arn
}

output "app_host_role_name" {
  description = "IAM role name of the app host."
  value       = aws_iam_role.app_host.name
}

output "eip_allocation_id" {
  description = "Allocation ID of the Elastic IP, for reference/debugging."
  value       = aws_eip.app_host.id
}
