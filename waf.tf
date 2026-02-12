resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${local.resource_prefix}-allowed-ips"
  description        = "Allowed IPs for CloudFront - ${local.workspace}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = []

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-waf-ip-set"
    }
  )
}

resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name        = "${local.resource_prefix}-cloudfront-waf"
  description = "WAF para CloudFront - ${local.workspace}"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

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

resource "aws_wafv2_web_acl" "alb_waf" {
  name        = "${local.resource_prefix}-alb-waf"
  description = "WAF para ALB - ${local.workspace}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

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


resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}


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
