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
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "service-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
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

# ── SECRETS (SSM Parameter Store) ────────────────────────────
# Created before db so the app host's Ansible role always has
# somewhere in SSM to read credentials from, in this region.
module "secrets" {
  source       = "../../modules/secrets"
  project_name = var.project_name
  environment  = var.environment
  db_username  = var.db_username
  db_password  = var.db_password
  tags         = var.global_tags
}

module "db" {
  source                  = "../../modules/db"
  vpc_id                  = module.vpc.vpc_id
  database_subnets        = module.vpc.database_subnets
  rds_security_group_id   = module.security.rds_security_group_id
  project_name            = var.project_name
  environment             = var.environment
  tags                    = var.global_tags
  db_username             = var.db_username
  db_password             = var.db_password
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  # Backups must be enabled (>0 days) for the DR environment to be able
  # to create a cross-region read replica from this instance.
}

module "messaging" {
  source       = "../../modules/messaging"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.global_tags
}

module "ecr" {
  source              = "../../modules/ecr"
  project_name        = var.project_name
  environment         = var.environment
  tags                = var.global_tags
  service_names       = ["api-gateway", "user-service", "product-service", "order-service"]
  replicate_to_region = var.dr_region
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
  sqs_queue_arns = [
    module.messaging.order_created_queue_arn,
    module.messaging.order_status_changed_queue_arn,
  ]
  ssm_parameter_arns_read = [
    module.secrets.db_username_parameter_arn,
    module.secrets.db_password_parameter_arn,
  ]
  # Primary always runs; only the standby (dr environment) is pilot-light.
  manage_instance_state = false
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {
    db_host              = module.db.rds_endpoint
    db_name              = "shop_master"
    aws_region           = var.aws_region
    ssm_parameter_prefix = "/${var.project_name}/${var.environment}/db"
  })
  filename = "../../../ansible/inventory/primary/group_vars/all.yml"
  # NOTE: db_role is a static literal inside the primary all.yml.tpl
  # itself (see that file) rather than a Terraform variable, since it
  # never changes for this environment.
}

resource "local_file" "ansible_hosts" {
  content = templatefile("${path.module}/templates/hosts.ini.tpl", {
    ec2_public_ip = module.compute.public_ip
  })
  filename = "../../../ansible/inventory/primary/hosts.ini"
}
