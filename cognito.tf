resource "aws_cognito_user_pool" "main" {
  name = "iac-user-pool"

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = {
    Name = "IAC-User-Pool"
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "iac-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false # Para SPAs/Web Apps usualmente es false

  # Expiración de tokens (30 minutos según requisitos)
  access_token_validity = 30
  id_token_validity     = 30
  token_validity_units {
    access_token = "minutes"
    id_token     = "minutes"
  }

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

resource "aws_cognito_user_group" "persona" {
  name         = "Persona"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Grupo para usuarios solicitantes de empleo"
  precedence   = 10
}

resource "aws_cognito_user_group" "empresa" {
  name         = "Empresa"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Grupo para usuarios contratistas"
  precedence   = 5
}
