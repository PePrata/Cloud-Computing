output "db_username_parameter_arn" {
  value       = aws_ssm_parameter.db_username.arn
  description = "ARN of the SSM parameter holding the DB username, granted to the app host role."
}

output "db_password_parameter_arn" {
  value       = aws_ssm_parameter.db_password.arn
  description = "ARN of the SSM parameter holding the DB password, granted to the app host role."
}

output "db_username_parameter_name" {
  value       = aws_ssm_parameter.db_username.name
}

output "db_password_parameter_name" {
  value       = aws_ssm_parameter.db_password.name
}
