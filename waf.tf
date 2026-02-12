# ===================================================
# WAF para CloudFront (IP-set y reglas)
# ===================================================

# IP Set para permitir acceso desde IPs específicas (opcional)
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${local.resource_prefix}-allowed-ips"
  description        = "Allowed IPs for CloudFront - ${local.workspace}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = [] # Puedes añadir IPs aquí si necesitas restringir acceso

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-waf-ip-set"
    }
  )
}

# Web ACL para CloudFront
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name        = "${local.resource_prefix}-cloudfront-waf"
  description = "WAF para CloudFront - ${local.workspace}"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Regla 1: Common Rule Set (SQL Injection, XSS, etc.)
  rule {
    name     = "${local.resource_prefix}-common-rule-set"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Excluir algunas reglas si es necesario
        rule_action_override {
          name = "SizeRestrictions_BODY"

          action_to_use {
            block {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: Known Bad Inputs
  rule {
    name     = "${local.resource_prefix}-known-bad-inputs"
    priority = 2

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
      metric_name                = "${local.resource_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: SQL Injection Protection
  rule {
    name     = "${local.resource_prefix}-sqli-protection"
    priority = 3

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
      metric_name                = "${local.resource_prefix}-sqli-protection"
      sampled_requests_enabled   = true
    }
  }

  # Regla 4: Rate Limiting (máximo 2000 requests en 5 minutos)
  rule {
    name     = "${local.resource_prefix}-rate-limit"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-cloudfront-waf"
    }
  )
}

# ===================================================
# WAF para ALB (Regional)
# ===================================================

# Web ACL para ALB
resource "aws_wafv2_web_acl" "alb_waf" {
  name        = "${local.resource_prefix}-alb-waf"
  description = "WAF para ALB - ${local.workspace}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Regla 1: Common Rule Set
  rule {
    name     = "${local.resource_prefix}-alb-common-rule-set"
    priority = 1

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
      metric_name                = "${local.resource_prefix}-alb-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # Regla 2: SQL Injection Protection
  rule {
    name     = "${local.resource_prefix}-alb-sqli-protection"
    priority = 2

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
      metric_name                = "${local.resource_prefix}-alb-sqli-protection"
      sampled_requests_enabled   = true
    }
  }

  # Regla 3: Rate Limiting para ALB
  rule {
    name     = "${local.resource_prefix}-alb-rate-limit"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.resource_prefix}-alb-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-alb-waf"
    }
  )
}

# Asociar WAF a ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}

# CloudWatch Log Group para WAF (ALB)
resource "aws_cloudwatch_log_group" "waf_alb_logs" {
  name              = "/aws/waf/${local.resource_prefix}-alb"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-waf-alb-logs"
    }
  )
}

# Configurar logging de WAF para ALB
resource "aws_wafv2_web_acl_logging_configuration" "alb_logging" {
  resource_arn            = aws_wafv2_web_acl.alb_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_alb_logs.arn]

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.waf_alb_logs
  ]
}

# CloudWatch Log Group para WAF (CloudFront)
resource "aws_cloudwatch_log_group" "waf_cloudfront_logs" {
  name              = "/aws/waf/${local.resource_prefix}-cloudfront"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-waf-cloudfront-logs"
    }
  )
}

# Configurar logging de WAF para CloudFront
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront_logging" {
  resource_arn            = aws_wafv2_web_acl.cloudfront_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_cloudfront_logs.arn]

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.waf_cloudfront_logs
  ]
}
