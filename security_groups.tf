resource "aws_security_group" "alb_sg" {
  name        = "IAC-ALB-SG"
  description = "Security Group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "IAC-ALB-SG"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "IAC-App-SG"
  description = "Security Group for App Instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "IAC-App-SG"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "IAC-DB-SG"
  description = "Security Group for Aurora Database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "IAC-DB-SG"
  }
}

resource "aws_security_group" "endpoints_sg" {
  name        = "IAC-Endpoints-SG"
  description = "Security Group for VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "IAC-Endpoints-SG"
  }
}

# Security Group para Lambda
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

# Regla ingress para permitir tráfico entre Lambda e instancias si es necesario
resource "aws_security_group_rule" "lambda_to_app" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_sg.id
  security_group_id        = aws_security_group.app_sg.id
}

# Security Group para Redis (ElastiCache) - mejora de seguridad
resource "aws_security_group" "redis_sg" {
  name        = "IAC-Redis-SG"
  description = "Security Group for Redis/ElastiCache"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "IAC-Redis-SG"
  }
}
