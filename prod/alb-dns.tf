resource "aws_route53_zone" "public" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.route53_zone_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-zone"
    Environment = var.environment
  }
}

resource "aws_acm_certificate" "wordpress" {
  count             = var.enable_https ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-cert"
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = var.enable_https ? {
    for dvo in aws_acm_certificate.wordpress[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  zone_id         = local.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
}

resource "aws_acm_certificate_validation" "wordpress" {
  count                   = var.enable_https ? 1 : 0
  certificate_arn         = aws_acm_certificate.wordpress[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_lb" "wordpress" {
  name               = "${var.project_name}-${var.environment}-wp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-alb"
  }
}

resource "aws_lb_target_group" "wordpress" {
  name     = "${var.project_name}-${var.environment}-wp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-wordpress-tg"
  }
}

resource "aws_lb_target_group_attachment" "wordpress" {
  count = 2

  target_group_arn = aws_lb_target_group.wordpress.arn
  target_id        = aws_instance.wordpress[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_https ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.wordpress.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.wordpress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.wordpress[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_route53_record" "wordpress" {
  zone_id = local.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.wordpress.dns_name
    zone_id                = aws_lb.wordpress.zone_id
    evaluate_target_health = true
  }
}
