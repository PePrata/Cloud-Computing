variable "project_name" {
  type        = string
  description = "A global organizational string used to preface cluster elements."
}

variable "environment" {
  type        = string
  description = "The target phase categorization boundary moniker."
}

variable "tags" {
  type        = map(string)
  description = "Metadata collection tracking structures attached across newly built cloud resources."
}
