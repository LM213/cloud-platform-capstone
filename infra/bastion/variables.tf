variable "aws_region" {
  description = "Region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Tagging project"
  type        = string
  default     = "cloud-platform-capstone"
}

variable "vpc_id" {
  description = "VPC ID from network stack"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID to place bastion in"
  type        = string
}

variable "allow_ssh_from_cidr" {
  description = "CIDR allowed to SSH (e.g., 1.2.3.4/32). Leave empty to disable SSH ingress."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for bastion"
  type        = string
  default     = "t3.micro"
}

variable "volume_size_gb" {
  description = "EBS size (GB)"
  type        = number
  default     = 8
}
