data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_route53_zone" "existing_public" {
  count        = var.create_route53_zone ? 0 : 1
  name         = var.route53_zone_name
  private_zone = false
}

data "http" "terraform_runner_public_ip" {
  url = "https://checkip.amazonaws.com/"

  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  route53_zone_id            = var.create_route53_zone ? aws_route53_zone.public[0].zone_id : data.aws_route53_zone.existing_public[0].zone_id
  terraform_runner_public_ip = trimspace(data.http.terraform_runner_public_ip.response_body)
  effective_bastion_ssh_cidrs = length(var.bastion_allowed_ssh_cidrs) > 0 ? var.bastion_allowed_ssh_cidrs : [
    "${local.terraform_runner_public_ip}/32"
  ]
}
