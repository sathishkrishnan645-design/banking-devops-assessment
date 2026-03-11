variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Environment name (dev / staging / production)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "banking-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ec2_ami" {
  description = "Ubuntu 22.04 LTS AMI (ap-southeast-2)"
  type        = string
  default     = "ami-0d02292614a3b0df1"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for app server"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "ssl_certificate_arn" {
  description = "ACM SSL certificate ARN for HTTPS"
  type        = string
}

variable "ansible_control_ip" {
  description = "Ansible control node IP for SSH access rule"
  type        = string
  default     = "13.211.167.57"
}
