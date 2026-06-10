# ── 1. API GATEWAY ───────────────────────────────────────────
resource "aws_security_group" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api-gateway-sg"
  description = "Accepts inbound HTTP from the internet on port 8080."
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-api-gateway-sg" }
}

resource "aws_security_group_rule" "gateway_ingress_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_gateway.id
  description       = "Public HTTP traffic to api-gateway."
}

resource "aws_security_group_rule" "gateway_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api_gateway.id
  description       = "Unrestricted outbound for routing to internal services."
}

# ── 2. USER SERVICE ──────────────────────────────────────────
resource "aws_security_group" "user_service" {
  name        = "${var.project_name}-${var.environment}-user-service-sg"
  description = "Accepts HTTP from api-gateway (routing) and order-service (Feign)."
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
  description              = "api-gateway routes /api/users/** to user-service."
}

resource "aws_security_group_rule" "user_from_order_feign" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.user_service.id
  description              = "order-service Feign: GET /users/{id} to validate user before creating order."
}

resource "aws_security_group_rule" "user_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.user_service.id
  description       = "Unrestricted outbound for RDS access."
}

# ── 3. PRODUCT SERVICE ───────────────────────────────────────
resource "aws_security_group" "product_service" {
  name        = "${var.project_name}-${var.environment}-product-service-sg"
  description = "Accepts HTTP from api-gateway (routing) and order-service (Feign)."
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
  description              = "api-gateway routes /api/products/** to product-service."
}

resource "aws_security_group_rule" "product_from_order_feign" {
  type                     = "ingress"
  from_port                = 8082
  to_port                  = 8082
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.product_service.id
  description              = "order-service Feign: GET /products/{id} to validate product before creating order."
}

resource "aws_security_group_rule" "product_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.product_service.id
  description       = "Unrestricted outbound for RDS and MSK access."
}

# ── 4. ORDER SERVICE ─────────────────────────────────────────
resource "aws_security_group" "order_service" {
  name        = "${var.project_name}-${var.environment}-order-service-sg"
  description = "Accepts HTTP from api-gateway only. Initiates outbound Feign and Kafka calls."
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
  description              = "api-gateway routes /api/orders/** to order-service."
}

resource "aws_security_group_rule" "order_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.order_service.id
  description       = "Unrestricted outbound for Feign calls, RDS and MSK access."
}

# ── 5. RDS POSTGRESQL ────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Accepts PostgreSQL connections from the three services with a datasource."
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
  description              = "user-service JDBC connection to usersdb."
}

resource "aws_security_group_rule" "rds_from_product" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.product_service.id
  security_group_id        = aws_security_group.rds.id
  description              = "product-service JDBC connection to productsdb."
}

resource "aws_security_group_rule" "rds_from_order" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.rds.id
  description              = "order-service JDBC connection to ordersdb."
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Unrestricted outbound for RDS maintenance traffic."
}

# ── 6. MSK KAFKA ─────────────────────────────────────────────
resource "aws_security_group" "msk" {
  name        = "${var.project_name}-${var.environment}-msk-sg"
  description = "Accepts Kafka connections from order-service (producer) and product-service (consumer)."
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.project_name}-${var.environment}-msk-sg" }
}

resource "aws_security_group_rule" "msk_from_order_producer" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.order_service.id
  security_group_id        = aws_security_group.msk.id
  description              = "order-service Kafka producer: publishes to order-created topic."
}

resource "aws_security_group_rule" "msk_from_product_consumer" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.product_service.id
  security_group_id        = aws_security_group.msk.id
  description              = "product-service Kafka consumer: reads order-created topic to update stock."
}

resource "aws_security_group_rule" "msk_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.msk.id
  description       = "Unrestricted outbound for MSK broker replication traffic."
}
