resource "aws_secretsmanager_secret" "redis_auth_token" {
  name        = "${local.resource_prefix}-redis-auth-token"
  description = "Token de autenticaciÃ³n para Redis/ElastiCache"

  tags = {
    Name = "${local.resource_prefix}-redis-auth-token"
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({
    token = random_password.redis_auth_token.result
  })
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = true
  override_special = "!&#$^<>-"
}
