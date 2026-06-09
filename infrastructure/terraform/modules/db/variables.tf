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

variable "tags" {
  type        = map(string)
  description = "A mapping configuration block assigning resource ownership metadata metadata tags."
}
