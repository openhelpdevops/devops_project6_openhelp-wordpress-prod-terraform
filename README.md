# OpenHelp WordPress Production Terraform


This project provisions the AWS WordPress architecture with a separate Terraform state bootstrap stack and a production application stack.

Architecture

<img width="1672" height="941" alt="ChatGPT Image Aug 19, 2026, 10_37_45 AM" src="https://github.com/user-attachments/assets/0e96ae0b-4e92-4784-81cc-587457b3961a" />



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

## output

```bash
alb_dns_name = "openhelp-prod-wp-alb-659132022.us-east-1.elb.amazonaws.com"
bastion_allowed_ssh_cidrs = tolist([
  "217.119.64.150/32",
])
bastion_public_ip = "3.239.233.16"
database_secret_arn = "arn:aws:secretsmanager:us-east-1:720973523623:secret:openhelp/prod/wordpress/database-ieifjb"
efs_file_system_id = "fs-0268abf650e9775ec"
https_enabled = true
rds_endpoint = "openhelp-prod-wordpress-mysql.cofwmemysrbf.us-east-1.rds.amazonaws.com:3306"
rds_multi_az = false
route53_hosted_zone_id = "Z03499583HS0PQEVG9YYR"
  "ns-1453.awsdns-53.org",
  "ns-1911.awsdns-46.co.uk",
  "ns-79.awsdns-09.com",
  "ns-932.awsdns-52.net",
])
ssh_private_key_file = "./openhelp-prod-bastion.pem"
ssh_to_bastion = "ssh -i openhelp-prod-bastion.pem ec2-user@3.239.233.16"
ssh_to_wordpress_1 = "ssh -i openhelp-prod-bastion.pem -o \"ProxyCommand=ssh -i openhelp-prod-bastion.pem -W %h:%p ec2-user@3.239.233.16\" ec2-user@10.20.11.29"
ssh_to_wordpress_2 = "ssh -i openhelp-prod-bastion.pem -o \"ProxyCommand=ssh -i openhelp-prod-bastion.pem -W %h:%p ec2-user@3.239.233.16\" ec2-user@10.20.12.55"
ssh_to_wordpress_via_bastion = [
  "ssh -i openhelp-prod-bastion.pem -o \"ProxyCommand=ssh -i openhelp-prod-bastion.pem -W %h:%p ec2-user@3.239.233.16\" ec2-user@10.20.11.29",
  "ssh -i openhelp-prod-bastion.pem -o \"ProxyCommand=ssh -i openhelp-prod-bastion.pem -W %h:%p ec2-user@3.239.233.16\" ec2-user@10.20.12.55",
]
ssm_to_bastion = "aws ssm start-session --target i-0c1cdd57272cc0a30 --region us-east-1"
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:720973523623:targetgroup/openhelp-prod-wp-tg/675fa29b5c5ead3f"
waf_web_acl_arn = "arn:aws:wafv2:us-east-1:720973523623:regional/webacl/openhelp-prod-wordpress-waf/c606262a-d3ba-4784-bab5-754df3f5d770"
website_url = "https://openhelp.net"
wordpress_instance_ids = [
  "i-0b2f489442140bd6c",
  "i-0d9d4f3845fef3709",
]
wordpress_private_ips = [
  "10.20.11.29",
  "10.20.12.55",
]
```

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

access wp ec2 instance with

```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform\prod> ssh -i openhelp-prod-bastion.pem -o "ProxyCommand=ssh -i openhelp-prod-bastion.pem -W %h:%p ec2-user@3.239.233.16" ec2-user@10.20.11.29
```

verify shared file system mounted for uploads

<img width="577" height="195" alt="image" src="https://github.com/user-attachments/assets/00620958-d633-4be7-b43b-2d8c9804ed97" />


## Upgrade to the intended production RDS HA configuration(Not needed as we use free trial)

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
```bash
    cd prod
    terraform destroy
```
### 2. Destroy the state bootstrap stack last
```bash
    cd ../bootstrap-state
    terraform destroy
```
Do not destroy the state bucket before the production stack, because Terraform still needs the remote state while destroying the production resources.

For the full architecture, Terraform execution flow, security-group rules, DNS/ACM behavior, EFS, RDS, WAF, monitoring, and troubleshooting, see `ARCHITECTURE_AND_EXECUTION.md`.
# AWS WAF

AWS WAF stands for Web Application Firewall. It protects web applications from malicious HTTP and HTTPS requests before they reach the application.

We use AWS WAF to protect web applications from Layer 7 attacks. It inspects HTTP and HTTPS requests and can allow, block, or count traffic based on conditions such as IP address, request rate, URI, headers, SQL injection patterns, and known malicious inputs.

In our production WordPress architecture, WAF is associated with the Application Load Balancer, so malicious requests are blocked before they reach the EC2 instances.”

Typical rules you can configure include:

```bash
SQL injection protection
Cross-site scripting protection
AWS Managed Common Rule Set
Known bad inputs
IP block lists
Rate limiting
Geographic restrictions
Custom URI/header rules
```

First get the region:
```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> $REGION = aws configure get region
```
```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> $REGION
us-east-1
```
Then list your WAFs:
```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> aws wafv2 list-web-acls --scope REGIONAL --region $REGION --output table
```
--------------------------------------------------------------------------------------------------------------------------------------------                                                                                                                                                                                                                                                                 
|                                                                ListWebACLs                                                               |
+------------------------------------------+-----------------------------------------------------------------------------------------------+
|  NextMarker                              |  openhelp-prod-wordpress-waf                                                                  |
+------------------------------------------+-----------------------------------------------------------------------------------------------+
||                                                                 WebACLs                                                                ||
|+-------------+--------------------------------------------------------------------------------------------------------------------------+|
||  ARN        |  arn:aws:wafv2:us-east-1:720973523623:regional/webacl/openhelp-prod-wordpress-waf/c606262a-d3ba-4784-bab5-754df3f5d770   ||
||  Description|  Production WAF for WordPress ALB                                                                                        ||
||  Id         |  c606262a-d3ba-4784-bab5-754df3f5d770                                                                                    ||
||  LockToken  |  ebeccb9b-8376-4755-996f-8665651b3ee3                                                                                    ||
||  Name       |  openhelp-prod-wordpress-waf                                                                                             ||
|+-------------+--------------------------------------------------------------------------------------------------------------------------+|

Now automatically get the ID of your WAF:
```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> $WAFID = aws wafv2 list-web-acls --scope REGIONAL --region $REGION --query "WebACLs[?Name=='openhelp-prod-wordpress-waf'].Id | [0]" --output text
```
for powershell
```bash
PS C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> $WAFID
c606262a-d3ba-4784-bab5-754df3f5d770
```

for linux 
```bash
echo $WAFID
```
Now list the WAF rules:

 C:\Users\sreej\Desktop\sreejith_devops\openhelp-wordpress-prod-terraform> aws wafv2 get-web-acl --name openhelp-prod-wordpress-waf --scope REGIONAL --id $WAFID --region $REGION --query "WebACL.Rules[].[Priority,Name]" --output table                                                                                                                                                      
                                                                                                                                                                                                                                                                                                                                                                   
|             GetWebACL            |
+----+-----------------------------+
|  10|  BlockedIPv4                |
|  20|  AWSManagedCommonRules      |
|  30|  AWSManagedKnownBadInputs   |
|  40|  AWSManagedSQLiRules        |
|  50|  RateLimitPerIP             |
+----+-----------------------------+

Architecture will be like this:-

<img width="1672" height="941" alt="ChatGPT Image Aug 19, 2026, 12_36_56 PM" src="https://github.com/user-attachments/assets/c968c9bc-42f8-40a0-800c-58d305f35175" />

I aws ui search AWS WAF

<img width="1132" height="265" alt="image" src="https://github.com/user-attachments/assets/b93cbc31-659e-49fb-976e-f1a52fa67eb9" />

click on rules and understand rules

<img width="1636" height="257" alt="image" src="https://github.com/user-attachments/assets/24e4ac7f-de7c-4c75-8518-61c9e711be56" />


#how to block a access to site from a particular ip

Open AWS WAF & Shield.
Make sure the region is US East (N. Virginia) if that is where your ALB/WAF is deployed.
In the left menu, click IP sets.
Open the IP set used by your blocked rule. It may be named something like:
openhelp-prod-blocked-ipv4
Click Edit.
Under IP addresses, click Add IP address.
Enter the IP in CIDR format.

<img width="2703" height="713" alt="image" src="https://github.com/user-attachments/assets/d1b36b73-69ca-49bf-9dfb-c3076306dcd3" />


# cloud watch why we use it?


“Amazon CloudWatch is used to monitor AWS infrastructure and applications. It collects metrics, logs, and events from services such as EC2, RDS, ALB, and WAF. We use it to create dashboards and alarms so that we can detect performance issues, failures, or unusual behavior and respond quickly.”

In your WordPress architecture, CloudWatch can monitor:
```bash
EC2 CPU, network, status checks
Apache/WordPress logs
ALB request count, response time, 4xx/5xx errors
RDS CPU, connections, free storage, latency
WAF allowed and blocked requests
EFS metrics
CloudWatch alarms for problems
```

search for cloudwatch in was console
<img width="1413" height="291" alt="image" src="https://github.com/user-attachments/assets/312b4e0f-f4f6-42ed-9607-9451a9f27462" />


you can monitor multiple resources from cloudwatch

<img width="2326" height="832" alt="image" src="https://github.com/user-attachments/assets/2e701beb-0027-46d7-bb05-0d55b25ee8f2" />



