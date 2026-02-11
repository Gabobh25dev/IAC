resource "aws_iam_role" "lambda_execution_role" {
  name = "iac-lambda-messaging-role"

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

  tags = {
    Name = "IAC-Lambda-Execution-Role"
  }
}

resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "iac-lambda-sqs-policy"
  role = aws_iam_role.lambda_execution_role.id

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
        Resource = aws_sqs_queue.messaging_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.messaging_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_sns_policy" {
  name = "iac-lambda-sns-policy"
  role = aws_iam_role.lambda_execution_role.id

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

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "iac-lambda-secrets-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "${aws_secretsmanager_secret.aurora_db_secret.arn}*"
        ]
      }
    ]
  })
}

resource "null_resource" "create_lambda_dir" {
  provisioner "local-exec" {
    command = "mkdir -p '${path.module}/lambda' '${path.module}/lambda_layer/python'"
    interpreter = ["powershell", "-Command"]
  }
}

locals {
  lambda_handler_code = file("${path.module}/lambda_code.py")
}

resource "local_file" "lambda_handler" {
  filename = "${path.module}/lambda/index.py"
  content  = local.lambda_handler_code

  depends_on = [null_resource.create_lambda_dir]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"

  depends_on = [local_file.lambda_handler]
}

resource "aws_lambda_function" "message_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "iac-message-processor"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.messaging_topic.arn
      SQS_QUEUE_URL = aws_sqs_queue.messaging_queue.url
      ENVIRONMENT   = "Dev"
      LOG_LEVEL     = var.lambda_log_level
    }
  }

  layers = [aws_lambda_layer_version.common_utils.arn]

  vpc_config {
    subnet_ids         = [data.aws_subnet.default.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  tags = {
    Name = "IAC-Message-Processor"
  }

  depends_on = [
    aws_iam_role_policy.lambda_sqs_policy,
    aws_iam_role_policy_attachment.lambda_logs_policy
  ]
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = aws_sqs_queue.messaging_queue.arn
  function_name                      = aws_lambda_function.message_processor.function_name
  batch_size                         = var.lambda_batch_size
  maximum_batching_window_in_seconds = var.lambda_batching_window
  function_response_types            = ["ReportBatchItemFailures"]

  depends_on = [aws_iam_role_policy.lambda_sqs_policy]
}

locals {
  layer_utils_code = file("${path.module}/lambda_layer_code.py")
}

resource "null_resource" "create_layer_dir" {
  provisioner "local-exec" {
    command = "mkdir -p '${path.module}/lambda_layer/python'"
    interpreter = ["powershell", "-Command"]
  }
}

resource "local_file" "layer_utils" {
  filename = "${path.module}/lambda_layer/python/common_utils.py"
  content  = local.layer_utils_code

  depends_on = [null_resource.create_layer_dir]
}

data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_layer"
  output_path = "${path.module}/lambda_layer.zip"

  depends_on = [local_file.layer_utils]
}

resource "aws_lambda_layer_version" "common_utils" {
  layer_name            = "iac-common-utils"
  compatible_runtimes   = [var.lambda_runtime]
  filename              = data.archive_file.lambda_layer_zip.output_path
  source_code_hash      = data.archive_file.lambda_layer_zip.output_base64sha256
}

resource "aws_security_group" "lambda_sg" {
  name        = "IAC-Lambda-SG"
  description = "Security Group for Lambda Functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "IAC-Lambda-SG"
  }
}

data "aws_subnet" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.main.id]
  }
}


resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "iac-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when Lambda has errors processing messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.message_processor.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "iac-lambda-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when Lambda is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.message_processor.function_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.message_processor.function_name}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "IAC-Lambda-Logs"
  }
}
