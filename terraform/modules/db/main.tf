resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.database_subnets
  tags       = var.tags
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-${var.environment}-postgres"
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  max_allocated_storage  = 50
  storage_encrypted      = true
  db_name                = "shop_master"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_security_group_id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags                   = var.tags
}

output "rds_endpoint" { value = aws_db_instance.postgres.endpoint }