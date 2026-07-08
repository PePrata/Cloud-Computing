variable "aws_region" {
  type        = string
  description = "Target deployment region"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Target environment scope"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources."
  default     = "shop"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "key_name" {
  type        = string
  description = "Name of an EC2 key pair that already exists in AWS. Its private half must match the ANSIBLE_SSH_KEY GitHub secret."
}

variable "global_tags" {
  type        = map(string)
  description = "Mandatory evaluation metadata tags."
  default = {
    Project     = "microservices-shop"
    Environment = "dev"
    ManagedBy   = "terraform"
    Region      = "us-east-1"
  }
}
