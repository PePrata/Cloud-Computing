# SSM Parameter Store holds the DB credentials for this region so the
# app host can fetch them at deploy time via its IAM role, instead of
# the CI runner templating them into a plaintext file (see ansible
# role app-deploy). Both the primary and DR regions get their own copy
# of these parameters, because SSM Parameter Store is regional.

resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project_name}/${var.environment}/db/username"
  description = "Master username for the shop_master Postgres instance/replica in this region."
  type        = "SecureString"
  value       = var.db_username
  tags        = var.tags
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/db/password"
  description = "Master password for the shop_master Postgres instance/replica in this region. Must be identical in both regions: the DR replica inherits the primary's password until promoted."
  type        = "SecureString"
  value       = var.db_password
  tags        = var.tags
}
