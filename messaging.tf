# SNS/SQS Messaging Infrastructure
# Arquitectura: SNS Topic -> SQS Queue -> Lambda Processor

resource "aws_sns_topic" "messaging_topic" {
  name              = "iac-messaging-topic"
  display_name      = "IAC Application Events"
  kms_master_key_id = "alias/aws/sns"
  tags = {
    Name = "IAC-Messaging-Topic"
  }
}

resource "aws_sqs_queue" "messaging_queue" {
  name                       = "iac-messaging-queue"
  delay_seconds              = var.sqs_delay_seconds
  max_message_size           = var.sqs_max_message_size
  message_retention_seconds  = var.sqs_message_retention_seconds
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds

  tags = {
    Name = "IAC-Messaging-Queue"
  }
}

resource "aws_sqs_queue" "messaging_dlq" {
  name                      = "iac-messaging-queue-dlq"
  message_retention_seconds = var.sqs_dlq_retention_seconds

  tags = {
    Name = "IAC-Messaging-DLQ"
  }
}

resource "aws_sqs_queue_redrive_policy" "messaging_redrive" {
  queue_url = aws_sqs_queue.messaging_queue.id

  redrive_policy = jsonencode({
    maxReceiveCount     = var.sqs_max_receive_count
    deadLetterTargetArn = aws_sqs_queue.messaging_dlq.arn
  })
}

resource "aws_sns_topic_subscription" "messaging_subscription" {
  topic_arn = aws_sns_topic.messaging_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.messaging_queue.arn

  depends_on = [aws_sqs_queue_policy.allow_sns_to_sqs]
}

resource "aws_sqs_queue_policy" "allow_sns_to_sqs" {
  queue_url = aws_sqs_queue.messaging_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.messaging_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.messaging_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "messaging_rule" {
  name           = "iac-messaging-rule"
  description    = "Routing rule para eventos a SNS"
  event_bus_name = "default"
  state          = "ENABLED"

  event_pattern = jsonencode({
    source      = ["custom.app"]
    detail-type = ["Order Placed", "Payment Processed", "Status Update"]
  })

  tags = {
    Name = "IAC-Messaging-Rule"
  }
}

resource "aws_cloudwatch_event_target" "messaging_target" {
  rule      = aws_cloudwatch_event_rule.messaging_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.messaging_topic.arn

  role_arn = aws_iam_role.eventbridge_sns_role.arn
}

resource "aws_iam_role" "eventbridge_sns_role" {
  name = "iac-eventbridge-to-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "IAC-EventBridge-SNS-Role"
  }
}

resource "aws_iam_role_policy" "eventbridge_sns_policy" {
  name = "iac-eventbridge-sns-policy"
  role = aws_iam_role.eventbridge_sns_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.messaging_topic.arn
      }
    ]
  })
}

# CloudWatch Alarms para monitoreo

resource "aws_cloudwatch_metric_alarm" "dlq_messages_alarm" {
  alarm_name          = "iac-dlq-messages-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.dlq_alarm_threshold
  alarm_description   = "Alert when DLQ has too many messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.messaging_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_depth_alarm" {
  alarm_name          = "iac-queue-depth-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.queue_depth_alarm_threshold
  alarm_description   = "Alert when main queue is accumulating messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.messaging_queue.name
  }
}
