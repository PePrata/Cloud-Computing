output "repository_urls" {
  description = "Map of service name -> full ECR repository URL, e.g. api-gateway -> <account>.dkr.ecr.<region>.amazonaws.com/shop-api-gateway"
  value       = { for name, repo in aws_ecr_repository.service : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of service name -> ECR repository ARN."
  value       = { for name, repo in aws_ecr_repository.service : name => repo.arn }
}
