resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.project_name}-${var.environment}-kafka-cluster"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = var.private_subnets
    security_groups = [var.msk_security_group_id]

    storage_info {
      ebs_storage_info { volume_size = 10 }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT" # toggle to TLS before final release
      in_cluster    = true
    }
  }

  tags = var.tags
}