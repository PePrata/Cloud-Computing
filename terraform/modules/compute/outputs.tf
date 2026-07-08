output "public_ip" {
  description = "App host public IP — used to populate the Ansible hosts.ini before the playbook runs."
  value       = aws_instance.app_host.public_ip
}

output "instance_id" {
  description = "App host EC2 instance ID."
  value       = aws_instance.app_host.id
}
