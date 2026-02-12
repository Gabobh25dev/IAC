
resource "aws_sns_topic" "app_events" {
  name              = "${local.resource_prefix}-app-events"
  display_name      = "App Events Topic - ${local.workspace}"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-sns-topic"
    }
  )
}


resource "aws_sns_topic_policy" "app_events" {
  arn = aws_sns_topic.app_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublish"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.app_events.arn
      },
      {
        Sid    = "AllowSQSSubscribe"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.app_events.arn
      }
    ]
  })
}

resource "aws_sqs_queue" "message_queue" {
  name                      = "${local.resource_prefix}-message-queue"
  delay_seconds             = 0
  max_message_size          = 262144 # 256 KB
  message_retention_seconds = var.sqs_message_retention_seconds
  receive_wait_time_seconds = 20 # Long polling
  visibility_timeout_seconds = var.lambda_timeout + 30


  sqs_managed_sse_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-sqs-queue"
    }
  )
}


resource "aws_sqs_queue_policy" "message_queue" {
  queue_url = aws_sqs_queue.message_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.message_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.app_events.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "app_events_to_queue" {
  topic_arn            = aws_sns_topic.app_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.message_queue.arn
  raw_message_delivery = true
}

resource "aws_sqs_queue" "message_queue_dlq" {
  name                      = "${local.resource_prefix}-message-queue-dlq"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = var.sqs_message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-sqs-queue-dlq"
    }
  )
}


resource "aws_sqs_queue_redrive_policy" "message_queue" {
  queue_url       = aws_sqs_queue.message_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.message_queue_dlq.arn
    maxReceiveCount     = 3
  })
}
