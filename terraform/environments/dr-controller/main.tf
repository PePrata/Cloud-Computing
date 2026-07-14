# Wires together the primary and standby environments' outputs into the
# dr-controller module (Route 53 health checks + failover DNS + alarm +
# promotion Lambda). Kept as its own root module — rather than folded
# into dev or dr — because it needs both regions' state and otherwise
# creates a bootstrapping cycle (dev would need dr's outputs before dr
# exists, and vice-versa). Applied last in the pipeline, after dev and
# dr have both been applied at least once.
#
# Runs in us-east-1: Route 53 health-check CloudWatch metrics
# (AWS/Route53 namespace) only exist in that region regardless of which
# region is being checked. This happens to be the same region as the
# primary environment already.
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
  backend "s3" {
    bucket         = "service-tf-state-us-east-1-202373502174-us-east-1-an"
    key            = "environments/dr-controller/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "service-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = "service-tf-state-us-east-1-202373502174-us-east-1-an"
    key    = "environments/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "dr" {
  backend = "s3"
  config = {
    bucket = "service-tf-state-us-east-1-202373502174-us-east-1-an"
    key    = "environments/dr/terraform.tfstate"
    region = "us-east-1"
  }
}

module "dr_controller" {
  source = "../../modules/dr-controller"

  project_name   = var.project_name
  tags           = var.global_tags
  hosted_zone_id = var.hosted_zone_id
  dns_name       = var.dns_name

  primary_ip       = data.terraform_remote_state.primary.outputs.ec2_public_ip
  standby_ip       = data.terraform_remote_state.dr.outputs.ec2_public_ip
  primary_endpoint = data.terraform_remote_state.primary.outputs.ec2_public_ip
  standby_endpoint = data.terraform_remote_state.dr.outputs.ec2_public_ip

  alarm_evaluation_periods = var.alarm_evaluation_periods

  standby_region       = data.terraform_remote_state.dr.outputs.aws_region
  standby_replica_id   = data.terraform_remote_state.dr.outputs.rds_id
  standby_replica_arn  = data.terraform_remote_state.dr.outputs.rds_arn
  status_parameter_name = data.terraform_remote_state.dr.outputs.status_parameter_name
  status_parameter_arn   = data.terraform_remote_state.dr.outputs.status_parameter_arn
}
