variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "openhelp"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two availability zones are required."
  }
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.21.0/24", "10.20.22.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for Apache/WordPress servers."
  type        = string
  default     = "t3.micro"
}

variable "domain_name" {
  description = "WordPress DNS name, for example openhelp.net."
  type        = string
}

variable "route53_zone_name" {
  description = "Public DNS zone name, for example openhelp.net. Terraform can create it or use an existing Route 53 public hosted zone."
  type        = string
}

variable "create_route53_zone" {
  description = "When true, Terraform creates the public Route 53 hosted zone. When false, Terraform looks up an existing public hosted zone with route53_zone_name."
  type        = bool
  default     = true
}


variable "enable_https" {
  description = "Enable ACM DNS validation and the ALB HTTPS listener. Keep false until openhelp.net is delegated to the Route 53 hosted zone used by this stack."
  type        = bool
  default     = false
}

variable "db_name" {
  type    = string
  default = "wordpress"
}

variable "db_username" {
  type    = string
  default = "wpadmin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention in days. The current AWS Free plan may restrict this; use 1 for the Free-plan lab configuration."
  type        = number
  default     = 1

  validation {
    condition     = var.db_backup_retention_days >= 0 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 0 and 35."
  }
}

variable "db_multi_az" {
  description = "Deploy RDS as Multi-AZ. AWS Free plan allows only Single-AZ, so keep false there; set true on a paid account for production HA."
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "Maximum requests per 5-minute WAF evaluation window per source IP."
  type        = number
  default     = 2000
}

variable "waf_blocked_ipv4_cidrs" {
  description = "IPv4 CIDRs to explicitly block at WAF."
  type        = list(string)
  default     = []
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH to the bastion. Leave empty to automatically allow only the public IPv4 address of the machine running Terraform."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.bastion_allowed_ssh_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every bastion_allowed_ssh_cidrs value must be a valid IPv4 CIDR."
  }
}

variable "ssh_private_key_filename" {
  description = "Local filename Terraform creates for the generated SSH private key."
  type        = string
  default     = "openhelp-prod-bastion.pem"
}
