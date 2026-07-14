variable "project_name" {
  type    = string
  default = "shop"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID (an existing zone you own/delegate to) that the failover record is created in."
}

variable "dns_name" {
  type        = string
  description = "FQDN clients use to reach the app, e.g. shop.example.com. Must be inside the hosted zone above."
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
