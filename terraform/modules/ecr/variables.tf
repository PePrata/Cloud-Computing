variable "service_names" {
  type        = list(string)
  description = "Service short names to create ECR repos for, e.g. [\"api-gateway\", \"user-service\"]. Final repo name is \"shop-<name>\"."
}

variable "max_image_count" {
  type        = number
  description = "Number of most-recent images to retain per repository before older ones expire."
  default     = 10
}

variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources."
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g. dev, prod)."
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default     = {}
}
