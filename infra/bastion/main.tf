terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {} # uses the same remote backend configured at repo level
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project = var.project
    Managed = "terraform"
    Stack   = "bastion"
  }
}

# --- Security Group for bastion ---
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project}-bastion-sg"
  description = "Bastion security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.project}-bastion-sg" })
}

# Egress allow all (to reach SSM endpoints and yum repos)
resource "aws_vpc_security_group_egress_rule" "all_egress" {
  security_group_id = aws_security_group.bastion_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Optional SSH ingress from your IP
resource "aws_vpc_security_group_ingress_rule" "ssh_ingress" {
  count             = var.allow_ssh_from_cidr != "" ? 1 : 0
  security_group_id = aws_security_group.bastion_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.allow_ssh_from_cidr
  description       = "Allow SSH from your IP"
}

# --- IAM Role for SSM access ---
data "aws_iam_policy_document" "assume_role_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "bastion_role" {
  name               = "${var.project}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2.json
  tags               = local.tags
}

# Attach the AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.project}-bastion-profile"
  role = aws_iam_role.bastion_role.name
  tags = local.tags
}

# --- Find Amazon Linux 2023 AMI ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}


# --- EC2 Bastion ---
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  # Automatically install and start SSM Agent on boot
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
  EOF

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(local.tags, { Name = "${var.project}-bastion" })
}

