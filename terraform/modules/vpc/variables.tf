variable "project_name" {
  type        = string
}

variable "environment" {
  type        = string
  description = "The target phase categorization boundary moniker."
}

variable "tags" {
  type        = map(string)
  description = "Metadata collection tracking structures attached across newly built cloud resources."
}
