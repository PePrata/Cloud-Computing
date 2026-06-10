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
    key            = "envs/dev/terraform.tfstate"
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

module "db" {
  source                = "../../modules/db"
  vpc_id                = module.vpc.vpc_id
  database_subnets      = module.vpc.database_subnets
  rds_security_group_id = module.security.rds_security_group_id
  project_name          = var.project_name
  environment           = var.environment
  tags                  = var.global_tags
}

module "messaging" {
  source                = "../../modules/messaging"
  private_subnets       = module.vpc.private_subnets
  msk_security_group_id = module.security.msk_security_group_id
  project_name          = var.project_name
  environment           = var.environment
  tags                  = var.global_tags
}

# AUTOMATED ANSIBLE INVENTORY GENERATION
resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {
    rds_endpoint = module.db.rds_endpoint
    msk_brokers  = module.messaging.bootstrap_brokers
  })
  filename = "../../../ansible/inventory/group_vars/all.yml"
}

resource "local_file" "ansible_hosts" {
  content = templatefile("${path.module}/templates/hosts.ini.tpl", {
    ec2_public_ip = module.vpc.ec2_public_ip
  })
  filename = "../../../ansible/inventory/hosts.ini"
}
