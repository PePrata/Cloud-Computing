variable "private_subnets" {
  type        = list(string)
  description = "List of private network subnet identifiers allocated to run Apache Kafka cluster brokers."
}

variable "msk_security_group_id" {
  type        = string
  description = "Security group identifier managing client stream broker inbound traffic limits."
}

variable "project_name" {
  type        = string
  description = "A structural namespace prefix applied to cluster naming arrays."
}

variable "environment" {
  type        = string
  description = "Moniker matching deployment scopes (e.g., dev, staging, prod)."
}

variable "tags" {
  type        = map(string)
  description = "Operational tags applied to the AWS MSK resources."
}
