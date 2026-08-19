terraform {
  backend "s3" {
    bucket       = "openhelp-prod-720973523623-tfstate"
    key          = "wordpress/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
