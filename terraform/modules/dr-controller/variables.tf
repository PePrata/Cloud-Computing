variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to DR-controller resources."
  default     = {}
}

variable "primary_endpoint" {
  type        = string
  description = "FQDN or IP the primary health check polls (this project passes the app host's Elastic IP)."
}

variable "standby_endpoint" {
  type        = string
  description = "FQDN or IP the standby health check polls (this project passes the app host's Elastic IP)."
}

variable "health_check_port" {
  type        = number
  description = "Port the health checks connect to (api-gateway)."
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "HTTP path the health checks request (Spring Boot Actuator health endpoint)."
  default     = "/actuator/health"
}

variable "alarm_evaluation_periods" {
  type        = number
  description = "Number of consecutive 1-minute periods the primary health check must report unhealthy before the CloudWatch alarm fires and triggers replica promotion. 1 = fast detection for drills/demos; 2-3 recommended for production to avoid promoting on a transient blip."
  default     = 1
}

variable "standby_region" {
  type        = string
  description = "AWS region of the standby replica, passed to the Lambda's boto3 RDS client."
}

variable "standby_replica_id" {
  type        = string
  description = "DB instance identifier of the standby read replica to promote."
}

variable "standby_replica_arn" {
  type        = string
  description = "ARN of the standby read replica — scopes the Lambda's rds:PromoteReadReplica/DescribeDBInstances permissions."
}

variable "status_parameter_name" {
  type        = string
  description = "SSM parameter name (in the standby region) the Lambda flips to \"active\" after promotion; the standby app's Ansible/docker-compose template reads it to know it is now the writable primary."
}

variable "status_parameter_arn" {
  type        = string
  description = "ARN of the above SSM parameter, for the Lambda's IAM policy."
}
