resource "aws_wafv2_ip_set" "blocked" {
  name               = "${var.project_name}-${var.environment}-blocked-ipv4"
  description        = "Explicitly blocked IPv4 networks"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.waf_blocked_ipv4_cidrs
}

resource "aws_wafv2_web_acl" "wordpress" {
  name        = "${var.project_name}-${var.environment}-wordpress-waf"
  description = "Production WAF for WordPress ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "BlockedIPv4"
    priority = 10

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockedIPv4"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedCommonRules"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedCommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedKnownBadInputs"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedKnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedSQLiRules"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedSQLiRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 50

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIP"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-wordpress-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-waf"
  }
}

resource "aws_wafv2_web_acl_association" "wordpress" {
  resource_arn = aws_lb.wordpress.arn
  web_acl_arn  = aws_wafv2_web_acl.wordpress.arn
}
