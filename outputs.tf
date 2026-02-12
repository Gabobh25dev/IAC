
output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

output "cloudfront_domain_name" {
  description = "Domain name de CloudFront Distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID de CloudFront Distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "sns_topic_arn" {
  description = "ARN del SNS Topic para eventos"
  value       = aws_sns_topic.app_events.arn
}

output "sns_topic_name" {
  description = "Nombre del SNS Topic"
  value       = aws_sns_topic.app_events.name
}

output "sqs_queue_url" {
  description = "URL de la SQS Queue"
  value       = aws_sqs_queue.message_queue.url
}

output "sqs_queue_arn" {
  description = "ARN de la SQS Queue"
  value       = aws_sqs_queue.message_queue.arn
}

output "sqs_dlq_url" {
  description = "URL de la SQS Dead Letter Queue"
  value       = aws_sqs_queue.message_queue_dlq.url
}


output "lambda_function_name" {
  description = "Nombre de la funciÃ³n Lambda"
  value       = aws_lambda_function.message_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN de la funciÃ³n Lambda"
  value       = aws_lambda_function.message_processor.arn
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_log_group_name" {
  description = "Nombre del CloudWatch Log Group de Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}





output "cloudfront_waf_id" {
  description = "ID del WAF para CloudFront"
  value       = aws_wafv2_web_acl.cloudfront_waf.id
}

output "alb_waf_id" {
  description = "ID del WAF para ALB"
  value       = aws_wafv2_web_acl.alb_waf.id
}

output "waf_cloudfront_log_group" {
  description = "CloudWatch Log Group para WAF CloudFront"
  value       = aws_cloudwatch_log_group.waf_cloudfront_logs.name
}

output "waf_alb_log_group" {
  description = "CloudWatch Log Group para WAF ALB"
  value       = aws_cloudwatch_log_group.waf_alb_logs.name
}





output "hosted_zone_id" {
  description = "ID de la Hosted Zone"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Nombre de la Hosted Zone"
  value       = data.aws_route53_zone.main.name
}

output "frontend_domain" {
  description = "Dominio del Frontend"
  value       = aws_route53_record.frontend.fqdn
}

output "api_domain" {
  description = "Dominio del API"
  value       = aws_route53_record.api.fqdn
}

output "route53_health_check_id" {
  description = "ID del Route53 Health Check para ALB"
  value       = aws_route53_health_check.alb.id
}





output "lambda_sg_id" {
  description = "ID del Security Group de Lambda"
  value       = aws_security_group.lambda_sg.id
}

output "redis_sg_id" {
  description = "ID del Security Group de Redis"
  value       = aws_security_group.redis_sg.id
}

output "environment" {
  description = "Ambiente (workspace actual)"
  value       = local.workspace
}

output "resource_prefix" {
  description = "Prefijo de nombres de recursos"
  value       = local.resource_prefix
}

output "common_tags" {
  description = "Tags comunes aplicados a recursos"
  value       = local.common_tags
  sensitive   = false
}
