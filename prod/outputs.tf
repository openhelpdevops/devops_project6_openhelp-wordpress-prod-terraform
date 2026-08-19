output "website_url" {
  value = "${var.enable_https ? "https" : "http"}://${var.domain_name}"
}

output "alb_dns_name" {
  value = aws_lb.wordpress.dns_name
}

output "wordpress_instance_ids" {
  value = aws_instance.wordpress[*].id
}

output "efs_file_system_id" {
  value = aws_efs_file_system.wordpress.id
}

output "rds_endpoint" {
  description = "RDS DNS endpoint used by WordPress. This is a DNS endpoint, not a static VIP."
  value       = aws_db_instance.wordpress.endpoint
}

output "database_secret_arn" {
  value = aws_secretsmanager_secret.wordpress_db.arn
}

output "waf_web_acl_arn" {
  value = aws_wafv2_web_acl.wordpress.arn
}

output "bastion_public_ip" {
  description = "Public IPv4 address of the bastion host."
  value       = aws_instance.bastion.public_ip
}

output "bastion_allowed_ssh_cidrs" {
  description = "CIDRs currently permitted to SSH to the bastion."
  value       = local.effective_bastion_ssh_cidrs
}

output "ssh_private_key_file" {
  description = "Private key generated locally by Terraform for bastion and WordPress SSH access."
  value       = local_sensitive_file.ssh_private_key.filename
}

output "ssh_to_bastion" {
  description = "SSH command for the bastion host."
  value       = "ssh -i ${var.ssh_private_key_filename} ec2-user@${aws_instance.bastion.public_ip}"
}

output "wordpress_private_ips" {
  description = "Private IPv4 addresses of the two WordPress instances."
  value       = aws_instance.wordpress[*].private_ip
}

output "ssh_to_wordpress_via_bastion" {
  description = "SSH commands for the private WordPress instances through the bastion. The private key stays on your workstation."
  value = [
    for instance in aws_instance.wordpress :
    "ssh -i ${var.ssh_private_key_filename} -o \"ProxyCommand=ssh -i ${var.ssh_private_key_filename} -W %h:%p ec2-user@${aws_instance.bastion.public_ip}\" ec2-user@${instance.private_ip}"
  ]
}

output "ssh_to_wordpress_1" {
  description = "SSH command for WordPress instance 1 through the bastion."
  value       = "ssh -i ${var.ssh_private_key_filename} -o \"ProxyCommand=ssh -i ${var.ssh_private_key_filename} -W %h:%p ec2-user@${aws_instance.bastion.public_ip}\" ec2-user@${aws_instance.wordpress[0].private_ip}"
}

output "ssh_to_wordpress_2" {
  description = "SSH command for WordPress instance 2 through the bastion."
  value       = "ssh -i ${var.ssh_private_key_filename} -o \"ProxyCommand=ssh -i ${var.ssh_private_key_filename} -W %h:%p ec2-user@${aws_instance.bastion.public_ip}\" ec2-user@${aws_instance.wordpress[1].private_ip}"
}

output "ssm_to_bastion" {
  description = "Alternative bastion access through AWS Systems Manager Session Manager."
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "target_group_arn" {
  description = "ALB target group ARN for target-health validation."
  value       = aws_lb_target_group.wordpress.arn
}

output "route53_hosted_zone_id" {
  description = "Route 53 public hosted zone ID used for the WordPress DNS records."
  value       = local.route53_zone_id
}

output "route53_name_servers" {
  description = "Authoritative Route 53 name servers when Terraform creates the hosted zone. Configure these at your domain registrar. Empty when an existing hosted zone is used."
  value       = var.create_route53_zone ? aws_route53_zone.public[0].name_servers : []
}

output "https_enabled" {
  description = "Whether ACM/HTTPS is enabled for the ALB."
  value       = var.enable_https
}

output "rds_multi_az" {
  description = "Whether the current RDS deployment uses Multi-AZ."
  value       = var.db_multi_az
}
