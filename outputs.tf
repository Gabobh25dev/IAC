output "sns_topic_arn" {
  description = "ARN del topic SNS para publicar mensajes"
  value       = aws_sns_topic.messaging_topic.arn
}

output "sns_topic_name" {
  description = "Nombre del topic SNS"
  value       = aws_sns_topic.messaging_topic.name
}

output "sqs_queue_url" {
  description = "URL de la cola SQS para enviar mensajes"
  value       = aws_sqs_queue.messaging_queue.url
}

output "sqs_queue_arn" {
  description = "ARN de la cola SQS"
  value       = aws_sqs_queue.messaging_queue.arn
}

output "sqs_dlq_url" {
  description = "URL de la Dead Letter Queue para mensajes fallidos"
  value       = aws_sqs_queue.messaging_dlq.url
}

output "sqs_dlq_arn" {
  description = "ARN de la Dead Letter Queue"
  value       = aws_sqs_queue.messaging_dlq.arn
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda procesadora"
  value       = aws_lambda_function.message_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.message_processor.arn
}

output "lambda_role_arn" {
  description = "ARN del IAM role de Lambda"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_log_group" {
  description = "CloudWatch Log Group para Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "eventbridge_rule_arn" {
  description = "ARN de la regla EventBridge (opcional)"
  value       = aws_cloudwatch_event_rule.messaging_rule.arn
}

output "cloudwatch_alarm_dlq" {
  description = "Nombre de la alarma CloudWatch para DLQ"
  value       = aws_cloudwatch_metric_alarm.dlq_messages_alarm.alarm_name
}

output "cloudwatch_alarm_queue_depth" {
  description = "Nombre de la alarma CloudWatch para cola principal"
  value       = aws_cloudwatch_metric_alarm.queue_depth_alarm.alarm_name
}

output "cloudwatch_alarm_lambda_errors" {
  description = "Nombre de la alarma CloudWatch para errores de Lambda"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
}

output "messaging_configuration" {
  description = "Configuración completa de mensajería para otros módulos"
  value = {
    sns_topic_arn    = aws_sns_topic.messaging_topic.arn
    sqs_queue_url    = aws_sqs_queue.messaging_queue.url
    sqs_queue_arn    = aws_sqs_queue.messaging_queue.arn
    lambda_arn       = aws_lambda_function.message_processor.arn
    lambda_role_arn  = aws_iam_role.lambda_execution_role.arn
  }
}

output "messaging_setup_complete" {
  description = "Confirmación de que la infraestructura de mensajería está lista"
  value       = "✓ SNS Topic, SQS Queue (+ DLQ), y Lambda Function han sido creados exitosamente"
}

output "next_steps" {
  description = "Próximos pasos para usar la infraestructura"
  value = <<-EOT
    1. Guardar los outputs anteriores (especialmente SNS_TOPIC_ARN y SQS_QUEUE_URL)
    2. Integrar en tu aplicación:
       - EC2: Publicar a SNS con boto3
       - S3: Configurar S3 events
       - Aurora: Use triggers + Lambda
    3. Monitorear con CloudWatch:
       - aws logs tail /aws/lambda/iac-message-processor --follow
    4. Testing: Publicar un evento de prueba
       - aws sns publish --topic-arn <SNS_ARN> --message '{"detail-type":"Test","detail":{}}'
  EOT
}
