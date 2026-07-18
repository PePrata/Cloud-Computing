terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  backend "s3" {
    bucket         = "service-tf-state-us-east-1-202373502174-us-east-1-an"
    key            = "environments/dr/terraform.tfstate"
    region         = "us-east-1" # bucket's own region — unrelated to what gets deployed
    dynamodb_table = "service-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region # standby region, e.g. eu-west-1
}

# Reads the primary environment's state so the standby is a parameterized
# instance of it: same modules, same account, different region, wired to
# the primary's RDS instance (as replication source) instead of creating
# an independent database.
data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = "service-tf-state-us-east-1-202373502174-us-east-1-an"
    key    = "environments/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

# The default AWS-managed key for RDS, in this (destination) region.
# Free, no setup, already exists in every region — used instead of a
# customer-managed key since this project doesn't need custom key
# rotation/policy control. Cross-region encrypted read replicas need an
# explicit key in the destination region; they cannot inherit the
# source region's key because KMS keys are region-scoped.
data "aws_kms_key" "rds_default" {
  key_id = "alias/aws/rds"
}

module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.global_tags
}

module "security" {
  source       = "../../modules/security"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
}

# Same credentials as the primary — a read replica inherits them and
# will keep using them after promotion, so both regions' SSM copies
# must match.
module "secrets" {
  source       = "../../modules/secrets"
  project_name = var.project_name
  environment  = var.environment
  db_username  = data.terraform_remote_state.primary.outputs.db_username
  db_password  = data.terraform_remote_state.primary.outputs.db_password
  tags         = var.global_tags
}

# A non-secret status flag the standby's docker-compose render reads:
# "standby" while it's a pilot-light read replica, "active" once the
# DR-controller Lambda promotes it. Ansible's app-deploy role reads this
# alongside the DB credentials.
resource "aws_ssm_parameter" "dr_status" {
  name  = "/${var.project_name}/${var.environment}/status"
  type  = "String"
  value = "standby"

  lifecycle {
    # The DR-controller Lambda flips this to "active" outside of
    # Terraform during a real/drill failover; don't fight it back to
    # "standby" on every apply.
    ignore_changes = [value]
  }

  tags = var.global_tags
}

module "db" {
  source                  = "../../modules/db"
  vpc_id                  = module.vpc.vpc_id
  database_subnets        = module.vpc.database_subnets
  rds_security_group_id   = module.security.rds_security_group_id
  project_name            = var.project_name
  environment             = var.environment
  tags                    = var.global_tags
  is_replica              = true
  source_db_arn           = data.terraform_remote_state.primary.outputs.rds_arn
  kms_key_id              = data.aws_kms_key.rds_default.arn
  instance_class           = "db.t4g.micro"
  backup_retention_period = var.db_backup_retention_period
}

module "compute" {
  source           = "../../modules/compute"
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
  project_name     = var.project_name
  environment      = var.environment
  key_name         = var.key_name
  tags             = var.global_tags
  security_group_ids = [
    module.security.api_gateway_security_group_id,
    module.security.user_service_security_group_id,
    module.security.product_service_security_group_id,
    module.security.order_service_security_group_id,
  ]
  # DR region doesn't own the SQS queues (order-created/order-status-changed
  # are only meaningful once this region is promoted to primary; recreating
  # them here in a pilot-light standby would just be idle spend). The
  # standby app host still needs the queue ARNs after a real failover —
  # documented as a known limitation/roadmap item in docs/limitations.md.
  sqs_queue_arns = []
  ssm_parameter_arns_read = [
    module.secrets.db_username_parameter_arn,
    module.secrets.db_password_parameter_arn,
    aws_ssm_parameter.dr_status.arn,
  ]
  # Pilot light: keep the standby host stopped (near-zero compute cost)
  # until a drill or real failover starts it.
  manage_instance_state = true
  instance_state        = var.standby_instance_state
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {
    db_host              = module.db.rds_endpoint
    db_name              = "shop_master"
    aws_region           = var.aws_region
    ssm_parameter_prefix = "/${var.project_name}/${var.environment}/db"
    ssm_status_parameter = aws_ssm_parameter.dr_status.name
  })
  filename = "../../../ansible/inventory/dr/group_vars/all.yml"
}

resource "local_file" "ansible_hosts" {
  content = templatefile("${path.module}/templates/hosts.ini.tpl", {
    ec2_public_ip = module.compute.public_ip
  })
  filename = "../../../ansible/inventory/dr/hosts.ini"
}
