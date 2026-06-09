terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Configured with your explicit S3 Bucket, Region, and DynamoDB State Lock Table
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

# 1. Base Custom VPC Networking (Allocated dynamically across us-east-1 AZs)
module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  tags         = var.global_tags
}

# 2. Strict Micro-segmented Security Groups
module "security" {
  source       = "../../modules/security"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
}

# 3. Isolated Persistence Database Layer
module "db" {
  source                = "../../modules/db"
  vpc_id                = module.vpc.vpc_id
  database_subnets      = module.vpc.database_subnets
  rds_security_group_id = module.security.rds_security_group_id
  project_name          = var.project_name
  environment           = var.environment
  tags                  = var.global_tags
}

# 4. Asynchronous Event-Streaming Layer (AWS MSK Kafka)
module "messaging" {
  source                = "../../modules/messaging"
  private_subnets       = module.vpc.private_subnets
  msk_security_group_id = module.security.msk_security_group_id
  project_name          = var.project_name
  environment           = var.environment
  tags                  = var.global_tags
}
