output "vpc_id" {
  value = module.vpc.vpc_id
}

output "rds_endpoint" {
  value       = module.db.rds_endpoint
  description = "Standby replica endpoint — unchanged by promotion, so this stays valid after failover."
}

output "rds_id" {
  value       = module.db.rds_id
  description = "Standby DB instance identifier — consumed by the dr-controller environment as the promotion target."
}

output "rds_arn" {
  value       = module.db.rds_arn
  description = "Standby replica ARN — consumed by the dr-controller environment to scope the Lambda's IAM policy."
}

output "ec2_instance_id" {
  value = module.compute.instance_id
}

output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "Standby EC2 Elastic IP — used by deploy.yml to update the Ansible dr inventory, and by the dr-controller environment as the Route 53 secondary failover target."
}

output "status_parameter_name" {
  value       = aws_ssm_parameter.dr_status.name
  description = "SSM parameter the dr-controller Lambda flips to 'active' on promotion."
}

output "status_parameter_arn" {
  value = aws_ssm_parameter.dr_status.arn
}

output "aws_region" {
  value = var.aws_region
}
