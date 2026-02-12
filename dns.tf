# Route53 DNS Configuration
data "aws_route53_zone" "main" {
  name = var.hosted_zone_name
}

# Frontend DNS
resource "aws_route53_record" "frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.frontend_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "frontend_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.frontend_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# API DNS
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.api_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.api_domain
  type    = "AAAA"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ALB Health Check
resource "aws_route53_health_check" "alb" {
  fqdn              = aws_lb.main.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  measure_latency   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-route53-health-check-alb"
    }
  )
}

# Additional DNS Records
# Registro TXT para validación DKIM (comentado)
# resource "aws_route53_record" "example_txt" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "_dmarc.${var.hosted_zone_name}"
#   type    = "TXT"
#   ttl     = 300
#   records = ["v=DMARC1; p=none;"]
# }

# Ejemplo: Registro MX (comentado)
# resource "aws_route53_record" "example_mx" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = var.hosted_zone_name
#   type    = "MX"
#   ttl     = 300
#   records = ["10 mail.${var.hosted_zone_name}"]
# }

# ===================================================
# Traffic Policy (Opcional - para failover)
# ===================================================

# Ejemplo de failover DNS (comentado)
# resource "aws_route53_record" "api_failover" {
#   zone_id         = data.aws_route53_zone.main.zone_id
#   name            = local.api_domain
#   type            = "A"
#   set_identifier  = "primary"
#   failover_routing_policy {
#     type = "PRIMARY"
#   }
#   alias {
#     name                   = aws_lb.main.dns_name
#     zone_id                = aws_lb.main.zone_id
#     evaluate_target_health = true
#   }
# }
