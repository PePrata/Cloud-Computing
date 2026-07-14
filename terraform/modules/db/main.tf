resource "aws_db_subnet_group" "rds" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.database_subnets
  tags       = var.tags
}

# ── PRIMARY INSTANCE ──────────────────────────────────────────
# Created when is_replica = false (the normal case in every region that
# is not acting as the DR read-replica target).
resource "aws_db_instance" "postgres" {
  count = var.is_replica ? 0 : 1

  identifier              = "${var.project_name}-${var.environment}-postgres"
  engine                  = "postgres"
  engine_version          = "16.12"
  instance_class          = var.instance_class
  allocated_storage       = 20
  max_allocated_storage   = 50
  storage_encrypted       = true
  db_name                 = "shop_master"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [var.rds_security_group_id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately
  tags                    = var.tags
}

# ── CROSS-REGION READ REPLICA (standby / DR region) ──────────
# Created when is_replica = true. A replica inherits engine/version/
# username/password from the source instance, so those arguments are
# not (and cannot be) repeated here. Cross-region replicas require the
# source to have backup_retention_period > 0, and need an explicit
# instance_class.
resource "aws_db_instance" "replica" {
  count = var.is_replica ? 1 : 0

  identifier              = "${var.project_name}-${var.environment}-postgres-replica"
  replicate_source_db     = var.source_db_arn
  instance_class          = var.instance_class
  storage_encrypted       = true
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [var.rds_security_group_id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately
  tags                    = var.tags
}
