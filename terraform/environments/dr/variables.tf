variable "aws_region" {
  type        = string
  description = "Standby/DR deployment region."
  default     = "eu-west-1"
}

variable "environment" {
  type        = string
  description = "Target environment scope."
  default     = "dr"
}

variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources. Must match the primary environment."
  default     = "shop"
}

variable "key_name" {
  type        = string
  description = "Name of an EC2 key pair that already exists in this region of the AWS account. Its private half must match the ANSIBLE_SSH_KEY GitHub secret."
}

variable "db_backup_retention_period" {
  type        = number
  description = "Automated backup retention in days for the replica. Kept at 1 (not 7) because Free Tier / sandbox AWS accounts reject higher retention periods with FreeTierRestrictionError on ModifyDBInstance/CreateDBInstance."
  default     = 1
}

variable "standby_instance_state" {
  type        = string
  description = "Desired power state of the standby EC2 host: 'stopped' for pilot-light (default, minimal cost), 'running' for warm-standby (faster RTO, higher cost). See docs/dr.md for the tradeoff."
  default     = "stopped"
}

variable "global_tags" {
  type        = map(string)
  description = "Mandatory evaluation metadata tags."
  default = {
    Project     = "microservices-shop"
    Environment = "dr"
    ManagedBy   = "terraform"
    Region      = "eu-west-1"
  }
}
