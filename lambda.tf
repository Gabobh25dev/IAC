# Rol IAM para Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-lambda-role"
    }
  )
}

# Política para acceso a SQS
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${local.resource_prefix}-lambda-sqs-policy"
  description = "Permite a Lambda consumir mensajes de SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.message_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.message_queue_dlq.arn
      }
    ]
  })
}

# Política para logs de CloudWatch
resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "${local.resource_prefix}-lambda-logs-policy"
  description = "Permite a Lambda escribir logs en CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${local.resource_prefix}-*"
      }
    ]
  })
}

# Adjuntar políticas
resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

# CloudWatch Log Group para Lambda (con retención de 7 días)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.resource_prefix}-message-processor"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-lambda-logs"
    }
  )
}

# Función Lambda (ejemplo simple - procesa mensajes de SQS)
resource "aws_lambda_function" "message_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.resource_prefix}-message-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  runtime          = "python3.12"

  environment {
    variables = {
      ENVIRONMENT = local.workspace
      PROJECT     = var.project_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_sqs
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-lambda"
    }
  )
}

# Archivo ZIP con el código de Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Event Source Mapping: SQS -> Lambda
resource "aws_lambda_event_source_mapping" "sqs_lambda" {
  event_source_arn                   = aws_sqs_queue.message_queue.arn
  function_name                      = aws_lambda_function.message_processor.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
}

# IAM Policy para permitir a SQS invocar Lambda
resource "aws_lambda_permission" "allow_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.message_processor.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.message_queue.arn
}

# IAM Policy para permitir a EC2 invocar Lambda
resource "aws_iam_policy" "ec2_lambda_policy" {
  name        = "${local.resource_prefix}-ec2-lambda-invoke-policy"
  description = "Permite a instancias EC2 invocar Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.message_processor.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.app_events.arn
      }
    ]
  })
}

# Adjuntar policy de Lambda a rol de EC2
resource "aws_iam_role_policy_attachment" "ec2_lambda_invoke" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_lambda_policy.arn
}
