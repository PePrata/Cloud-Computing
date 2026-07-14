variable "aws_region" {
  type        = string
  description = "Target deployment region (primary)"
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

variable "db_multi_az" {
  type        = bool
  description = "Enable RDS Multi-AZ (synchronous standby in a second AZ of us-east-1) for the primary instance. Complements, and is independent from, the cross-region read replica in the DR environment."
  default     = true
}

variable "db_backup_retention_period" {
  type        = number
  description = "Automated backup retention in days. Must be > 0 (AWS requirement) for the DR environment to create a cross-region read replica from this instance. Kept at 1 (not 7) because Free Tier / sandbox AWS accounts reject higher retention periods with FreeTierRestrictionError on ModifyDBInstance/CreateDBInstance. Directly bounds the achievable RPO — see docs/dr.md."
  default     = 1
}

variable "dr_region" {
  type        = string
  description = "AWS region of the standby/DR environment. Used here only to configure ECR cross-region replication so images built once are available to the standby app host."
  default     = "eu-west-1"
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
