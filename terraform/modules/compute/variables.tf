variable "vpc_id" {
  type        = string
  description = "The target Virtual Private Cloud network identifier."
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID where the app host is launched so it receives a public IP for Ansible/SSH."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Service security group IDs (api-gateway, user, product, order) attached to the single app host running all four containers."
}

variable "project_name" {
  type        = string
  description = "Prefix for infrastructure resources."
}

variable "environment" {
  type        = string
  description = "Target environment scope."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance size for the Docker Compose app host."
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "Name of an EC2 key pair that already exists in this AWS account. Its private half must match the ANSIBLE_SSH_KEY GitHub secret used by deploy.yml."
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed to SSH into the app host (used by the Ansible deploy step)."
  default     = "0.0.0.0/0"
}

variable "tags" {
  type        = map(string)
  description = "A mapping configuration block assigning resource ownership metadata tags."
}

variable "sqs_queue_arns" {
  type        = list(string)
  description = "ARNs of the SQS queues (order-created, order-status-changed) the app host needs to send/receive/delete messages on."
  default     = []
}
