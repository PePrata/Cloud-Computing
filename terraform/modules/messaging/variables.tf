variable "project_name" {
  type        = string
  description = "A structural namespace prefix applied to resource naming."
}

variable "environment" {
  type        = string
  description = "Moniker matching deployment scopes (e.g., dev, staging, prod)."
}

variable "tags" {
  type        = map(string)
  description = "Operational tags applied to the SQS queues."
}
