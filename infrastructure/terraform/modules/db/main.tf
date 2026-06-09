variable "vpc_id"                { type = string }
variable "database_subnets"      { type = list(string) }
variable "rds_security_group_id" { type = string }
variable "project_name"          { type = string }
variable "environment"           { type = string }
variable "tags"                  { type = map(string) }

resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.database_subnets
  tags       = var.tags
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-${var.environment}-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = "db.t4g.micro"
  db_name                = "shop_master"  
  username               = "dbadmin"
  password               = "SecureStudentPass123!"
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_security_group_id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags                   = var.tags
}

output "rds_endpoint" { value = aws_db_instance.postgres.endpoint }
