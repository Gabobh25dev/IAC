# ===================================================
# AWS Secrets Manager - Gestion Segura de Secretos
# ===================================================

# Secreto para Redis Auth Token
resource "aws_secretsmanager_secret" "redis_auth_token" {
  name        = "${local.resource_prefix}-redis-auth-token"
  description = "Token de autenticación para Redis/ElastiCache"

  tags = {
    Name = "${local.resource_prefix}-redis-auth-token"
  }
}

# Valor del secreto de Redis
resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({
    token = random_password.redis_auth_token.result
  })
}

# Generar token aleatorio seguro para Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = true
  # Redis requiere ciertos caracteres especiales
  override_special = "!&#$^<>-"
}
