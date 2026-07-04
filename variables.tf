variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "Master username for the RDS database"
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "Master password for the RDS database"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type for the application tier"
  type        = string
  default     = "t3.micro"
}
