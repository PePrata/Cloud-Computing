variable "vpc_id"       { type = string }
variable "project_name" { type = string }
variable "environment"  { type = string }

# 1. API GATEWAY SECURITY LAYER
resource "aws_security_group" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api-gateway-sg"
  description = "Handles inbound client API operations targeting public ALB nodes"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project_name}-${var.environment}-api-gateway-sg" }
}

resource "aws_security_group_rule" "gateway_ingress_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] 
  security_group_id = aws_security_group.api_gateway.id
}

resource "aws_security_group_rule" "gateway_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_gateway.id
}

# 2. ISOLATED COMPUTE TIERS (User, Product, Order Microservices)
resource "aws_security_group" "user_service" {
  name        = "${var.project_name}-${var.environment}-user-service-sg"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-user-service-sg" }
}

resource "aws_security_group_rule" "user_from_gateway" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.user_service.id
}

resource "aws_security_group" "product_service" {
  name        = "${var.project_name}-${var.environment}-product-service-sg"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-product-service-sg" }
}

resource "aws_security_group_rule" "product_from_gateway" {
  type                     = "ingress"
  from_port                = 8082
  to_port                  = 8082
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.product_service.id
}

resource "aws_security_group" "order_service" {
  name        = "${var.project_name}-${var.environment}-order-service-sg"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-order-service-sg" }
}

resource "aws_security_group_rule" "order_from_gateway" {
  type                     = "ingress"
  from_port                = 8083
  to_port                  = 8083
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.api_gateway.id
  security_group_id        = aws_security_group.order_service.id
}

resource "aws_security_group_rule" "services_egress_all" {
  for_each          = toset([aws_security_group.user_service.id, aws_security_group.product_service.id, aws_security_group.order_service.id])
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value
}

# 3. STORAGE SEGMENTATION LAYER (RDS PostgreSQL Database Instance)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Strict microservice isolation for transactional operations"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-rds-sg" }
}

resource "aws_security_group_rule" "rds_from_user" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.user_service.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_from_product" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.product_service.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_from_order" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.rds.id
}

# 4. EVENT STREAMING SECURITY LAYER (AWS MSK Cluster)
resource "aws_security_group" "msk" {
  name        = "${var.project_name}-${var.environment}-msk-sg"
  description = "Enforces decoupled asynchronous interaction limits across brokers"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-msk-sg" }
}

resource "aws_security_group_rule" "kafka_from_order_producer" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.msk.id
}

resource "aws_security_group_rule" "kafka_from_product_consumer" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.product_service.id
  security_group_id        = aws_security_group.msk.id
}
