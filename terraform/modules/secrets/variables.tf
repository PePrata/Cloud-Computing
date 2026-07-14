variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources / SSM parameter path."
}

variable "environment" {
  type        = string
  description = "Environment name, part of the SSM parameter path (e.g. dev, dr)."
}

variable "db_username" {
  type        = string
  description = "Master DB username to store in SSM Parameter Store."
}

variable "db_password" {
  type        = string
  description = "Master DB password to store in SSM Parameter Store."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the SSM parameters."
  default     = {}
}
