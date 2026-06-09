variable "private_subnets"       { type = list(string) }
variable "msk_security_group_id" { type = string }
variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "tags"                  { type = map(string) }

resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.project_name}-${var.environment}-kafka-cluster"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = var.private_subnets
    security_groups = [var.msk_security_group_id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT" # toggle to TLS before final release
      in_cluster    = true
    }
  }

  tags = var.tags
}

output "bootstrap_brokers" {
  value = aws_msk_cluster.kafka.bootstrap_brokers
}
