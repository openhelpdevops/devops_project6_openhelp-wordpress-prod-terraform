variable "aws_region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "openhelp"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}
