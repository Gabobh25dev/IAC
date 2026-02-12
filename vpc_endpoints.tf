resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app.id,
    aws_route_table.private_data.id
  ]

  tags = {
    Name = "IAC-S3-Endpoint"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  security_group_ids = [aws_security_group.endpoints_sg.id]

  tags = {
    Name = "IAC-SecretsManager-Endpoint"
  }
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sns"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  security_group_ids = [aws_security_group.endpoints_sg.id]

  tags = {
    Name = "IAC-SNS-Endpoint"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  security_group_ids = [aws_security_group.endpoints_sg.id]

  tags = {
    Name = "IAC-SQS-Endpoint"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  security_group_ids = [aws_security_group.endpoints_sg.id]

  tags = {
    Name = "IAC-Logs-Endpoint"
  }
}
