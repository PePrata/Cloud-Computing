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
  engine_version          = "16.13"
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

  # AWS applies minor-version upgrades automatically during maintenance
  # windows (auto_minor_version_upgrade defaults to true), which drifts
  # the running instance's version away from whatever is pinned here.
  # Terraform can't tell "AWS upgraded it" apart from "someone lowered
  # the pin", and refuses the resulting apparent downgrade either way.
  # Ignoring drift on this one attribute means Terraform stops fighting
  # AWS's own auto-upgrades; bump the value above deliberately when you
  # want to pin a specific version again.
  lifecycle {
    ignore_changes = [engine_version]
  }
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
  kms_key_id              = var.kms_key_id
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [var.rds_security_group_id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately
  tags                    = var.tags
}
