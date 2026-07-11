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

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-app-host" })
}
