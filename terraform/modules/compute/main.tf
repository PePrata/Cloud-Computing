data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── SSH ACCESS ────────────────────────────────────────────────
# None of the per-service security groups expose port 22; the app host
# needs its own inbound rule so the Ansible deploy step can reach it.
resource "aws_security_group" "app_host_ssh" {
  name        = "${var.project_name}-${var.environment}-app-host-ssh-sg"
  description = "Allows SSH from the CD pipeline so Ansible can configure and deploy the app host."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project_name}-${var.environment}-app-host-ssh-sg" })
}

resource "aws_security_group_rule" "app_host_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ssh_ingress_cidr]
  security_group_id = aws_security_group.app_host_ssh.id
  description       = "SSH access for Ansible provisioning."
}

# ── ECR PULL PERMISSIONS ─────────────────────────────────────
# The app-deploy Ansible role runs `aws ecr get-login-password` on the
# instance itself, so it needs an instance profile with ECR read access.
resource "aws_iam_role" "app_host" {
  name = "${var.project_name}-${var.environment}-app-host-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "app_host_ecr_readonly" {
  role       = aws_iam_role.app_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ── SQS ACCESS ────────────────────────────────────────────────
# order-service publishes to, and product-service consumes from, the
# queues created by modules/messaging. Both run as containers on this
# same host, so one role covers both directions.
resource "aws_iam_role_policy" "app_host_sqs" {
  count = length(var.sqs_queue_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-${var.environment}-app-host-sqs"
  role  = aws_iam_role.app_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = var.sqs_queue_arns
    }]
  })
}

# ── SSM PARAMETER STORE ACCESS ───────────────────────────────
# The Ansible app-deploy role fetches DB credentials from SSM Parameter
# Store directly on the instance at deploy time (via its IAM role),
# instead of receiving them as plaintext template variables rendered by
# the CI runner. Scoped to this project/environment's parameter path
# in this instance's own region only.
resource "aws_iam_role_policy" "app_host_ssm_read" {
  count = var.ssm_parameter_arns_read != null ? 1 : 0
  name  = "${var.project_name}-${var.environment}-app-host-ssm-read"
  role  = aws_iam_role.app_host.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      Resource = var.ssm_parameter_arns_read
    }]
  })
}

resource "aws_iam_instance_profile" "app_host" {
  name = "${var.project_name}-${var.environment}-app-host-profile"
  role = aws_iam_role.app_host.name
}

# ── EC2 APP HOST ──────────────────────────────────────────────
# Single Amazon Linux 2023 host running api-gateway, user-service,
# product-service and order-service together via docker compose.
resource "aws_instance" "app_host" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = concat(var.security_group_ids, [aws_security_group.app_host_ssh.id])
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.app_host.name
  associate_public_ip_address = true

  # A consola AWS define estes dois campos automaticamente quando lanças
  # pelo wizard; a API (e por isso o Terraform) não o faz por defeito, e
  # os defaults implícitos da API (cpu_credits=unlimited; volume size da
  # AMI) podem cair fora da validação de elegibilidade Free Tier mesmo
  # quando o instance_type em si está na lista de elegíveis da conta.
  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  # t3.micro só tem 1 GB de RAM para 4 JVMs — 2 GB de swap dá margem extra
  # contra OOM kills sem exigir uma instância maior (fora do Free Tier).
  user_data = <<-EOF2
    #!/bin/bash
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  EOF2

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-app-host" })
}

# ── STABLE ADDRESS FOR ROUTE 53 FAILOVER ─────────────────────
# The primary and standby EIPs are the two static targets that Route 53
# health checks and failover DNS records point at, so they must survive
# instance stop/start (pilot-light) and terraform apply cycles.
resource "aws_eip" "app_host" {
  domain   = "vpc"
  instance = aws_instance.app_host.id
  tags     = merge(var.tags, { Name = "${var.project_name}-${var.environment}-app-host-eip" })
}

# ── PILOT-LIGHT STATE CONTROL ────────────────────────────────
# aws_instance has no native "state" argument for stop/start — the
# aws_ec2_instance_state resource (provider >= 5.0) manages power state
# without forcing instance replacement. Used to keep the standby host
# stopped (pilot-light, near-zero compute cost) until a failover drill
# or real failover starts it.
resource "aws_ec2_instance_state" "app_host" {
  count       = var.manage_instance_state ? 1 : 0
  instance_id = aws_instance.app_host.id
  state       = var.instance_state
}
