# OpenHelp WordPress Production Terraform

This project provisions the AWS WordPress architecture with a separate Terraform state bootstrap stack and a production application stack.

## Current lab / AWS Free-plan settings

The checked-in `prod/terraform.tfvars` is configured for the current AWS Free plan restrictions that were encountered during deployment:

    domain_name         = "openhelp.net"
    route53_zone_name   = "openhelp.net"
    create_route53_zone = true
    enable_https        = false

    db_instance_class        = "db.t3.micro"
    db_backup_retention_days = 1
    db_multi_az              = false

`enable_https = false` is intentional for the first apply. Terraform creates the Route 53 public hosted zone and the ALB HTTP listener without waiting for ACM validation. After the registrar for `openhelp.net` has been delegated to the Route 53 name servers returned by Terraform, set `enable_https = true` and run `terraform apply` again. Terraform then requests the ACM certificate, creates the DNS validation records, validates the certificate, creates the HTTPS listener, and changes HTTP port 80 to redirect to HTTPS.

The current AWS Free plan allows RDS MySQL `db.t3.micro`, but it restricts deployment options to Single-AZ. Therefore the lab configuration uses `db_multi_az = false`. On a paid account, set `db_multi_az = true` and increase the backup retention period to the production value you require.

## Provisioning

### 1. Create the Terraform remote state infrastructure

    cd bootstrap-state
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan
    terraform apply

### 2. Provision the production application stack

    cd ../prod
    terraform init
    terraform fmt -recursive
    terraform validate
    terraform plan
    terraform apply

There is no backend file copying and no `-backend-config` argument.

### 3. Get Route 53 name servers

After the first production apply:

    terraform output route53_name_servers

If Terraform created the `openhelp.net` hosted zone, configure those four name servers at the registrar that owns `openhelp.net`. Route 53 automatically creates the NS and SOA records for a new public hosted zone, but public DNS will use that zone only after the domain is delegated to those name servers.

### 4. Verify DNS delegation

Windows PowerShell / Command Prompt:

    nslookup -type=NS openhelp.net

The result should show the same AWS name servers returned by:

    terraform output route53_name_servers

### 5. Enable HTTPS after DNS delegation works

Edit `prod/terraform.tfvars`:

    enable_https = true

Then run:

    terraform plan
    terraform apply

Terraform creates the ACM DNS validation records in Route 53 and waits for ACM to issue the certificate before creating the HTTPS listener.

## Access URLs and SSH

Website URL:

    terraform output -raw website_url

ALB DNS name:

    terraform output -raw alb_dns_name

SSH to bastion:

    terraform output -raw ssh_to_bastion

SSH to WordPress server 1 through bastion:

    terraform output -raw ssh_to_wordpress_1

SSH to WordPress server 2 through bastion:

    terraform output -raw ssh_to_wordpress_2

RDS endpoint:

    terraform output -raw rds_endpoint

The RDS endpoint is DNS, not a traditional static VIP.

## Upgrade to the intended production RDS HA configuration

The architecture supports Multi-AZ. The checked-in value is disabled only because the current AWS Free plan does not allow deployment options other than Single-AZ.

On a paid AWS plan, change:

    db_multi_az              = true
    db_backup_retention_days = 7

Then:

    terraform plan
    terraform apply

## Destroy order

Always destroy the application stack before the state stack.

### 1. Destroy production resources

    cd prod
    terraform destroy

### 2. Destroy the state bootstrap stack last

    cd ../bootstrap-state
    terraform destroy

Do not destroy the state bucket before the production stack, because Terraform still needs the remote state while destroying the production resources.

For the full architecture, Terraform execution flow, security-group rules, DNS/ACM behavior, EFS, RDS, WAF, monitoring, and troubleshooting, see `ARCHITECTURE_AND_EXECUTION.md`.
