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

module "db" {
  source                = "../../modules/db"
  vpc_id                = module.vpc.vpc_id
  database_subnets      = module.vpc.database_subnets
  rds_security_group_id = module.security.rds_security_group_id
  project_name          = var.project_name
  environment           = var.environment
  tags                  = var.global_tags
  db_username           = var.db_username
  db_password           = var.db_password
}

module "messaging" {
  source       = "../../modules/messaging"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.global_tags
}

module "ecr" {
  source        = "../../modules/ecr"
  project_name  = var.project_name
  environment   = var.environment
  tags          = var.global_tags
  service_names = ["api-gateway", "user-service", "product-service", "order-service"]
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
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/all.yml.tpl", {
    rds_endpoint = module.db.rds_endpoint
    db_username  = var.db_username
    db_password  = var.db_password
  })
  filename = "../../../ansible/inventory/group_vars/all.yml"
}

resource "local_file" "ansible_hosts" {
  content = templatefile("${path.module}/templates/hosts.ini.tpl", {
    ec2_public_ip = module.compute.public_ip
  })
  filename = "../../../ansible/inventory/hosts.ini"
}
