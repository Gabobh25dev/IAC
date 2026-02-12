# Rol para las instancias EC2
resource "aws_iam_role" "ec2_role" {
  name = "iac-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "IAC-EC2-Role"
  }
}

# Perfil de instancia para adjuntar el rol al Launch Template
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "iac-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Política para permitir acceso a Secrets Manager (Leer DB y Redis creds)
resource "aws_iam_policy" "secrets_policy" {
  name        = "iac-secrets-policy"
  description = "Permite leer secretos de la app"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_rds_cluster.main.master_user_secret[0].secret_arn
        ]
      }
    ]
  })
}

# Adjuntar política de Secrets Manager
resource "aws_iam_role_policy_attachment" "attach_secrets" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

# Adjuntar política gestionada para SSM (Permite conectar via Session Manager al EC2 sin SSH/puerto 22)
resource "aws_iam_role_policy_attachment" "attach_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
