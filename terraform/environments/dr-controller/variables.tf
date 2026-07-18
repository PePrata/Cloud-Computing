variable "project_name" {
  type    = string
  default = "shop"
}

variable "alarm_evaluation_periods" {
  type        = number
  description = "See the dr-controller module variable of the same name."
  default     = 1
}

variable "global_tags" {
  type    = map(string)
  default = {
    Project   = "microservices-shop"
    ManagedBy = "terraform"
  }
}
