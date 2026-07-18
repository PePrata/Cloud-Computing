variable "vpc_id" {
  type        = string
  description = "The target Virtual Private Cloud network identifier."
}

variable "database_subnets" {
  type        = list(string)
  description = "List of private subnet IDs isolated specifically for database tier data storage."
}

variable "rds_security_group_id" {
  type        = string
  description = "The micro-segmented firewall security group ID governing entry to PostgreSQL."
}

variable "project_name" {
  type        = string
  description = "A naming prefix used to guarantee consistent global element structures."
}

variable "environment" {
  type        = string
  description = "The targeted runtime system configuration environment string."
}

variable "db_username" {
  type        = string
  description = "Master username. Ignored when is_replica = true (inherited from the source instance)."
  default     = null
}

variable "db_password" {
  type        = string
  description = "Master password. Ignored when is_replica = true (inherited from the source instance)."
  default     = null
  sensitive   = true
}

variable "instance_class" {
  type        = string
  description = "RDS instance class for this instance (primary or replica)."
  default     = "db.t4g.micro"
}

variable "multi_az" {
  type        = bool
  description = "Whether the primary instance is deployed Multi-AZ (synchronous standby in a second AZ of the same region). Ignored when is_replica = true — cross-region replicas are single-AZ by default in this setup to control cost; promote-and-rebuild covers regional loss."
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups/snapshots. Must be > 0 for a cross-region read replica to be created from this instance, and directly determines the achievable RPO."
  default     = 7
}

variable "apply_immediately" {
  type        = bool
  description = "Whether Terraform changes to the DB instance are applied immediately instead of during the next maintenance window. Used during failover drills/promotions so state changes aren't delayed."
  default     = false
}

variable "is_replica" {
  type        = bool
  description = "If true, creates a cross-region read replica (aws_db_instance.replica) instead of a primary instance. Set true in the DR/standby environment."
  default     = false
}

variable "source_db_arn" {
  type        = string
  description = "ARN of the primary aws_db_instance to replicate from. Required when is_replica = true."
  default     = null
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN to encrypt the replica with, in the replica's own region. Required when is_replica = true and the source is encrypted: cross-region encrypted read replicas cannot inherit the source region's key (KMS keys are region-scoped), and AWS treats a missing key here as an attempt to create an unencrypted replica from an encrypted source, which it rejects outright. Not used for the primary instance (is_replica = false)."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "A mapping configuration block assigning resource ownership metadata metadata tags."
}
