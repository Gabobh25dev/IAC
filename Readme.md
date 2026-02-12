# Infraestructura como Código (IAC) con Terraform + AWS

## 📋 Descripción General

Este proyecto contiene la definición de infraestructura de AWS utilizando **Terraform**. La infraestructura incluye:

### Servicios Principales
- **Compute**: VPC, Subnets (públicas/privadas), EC2, Auto Scaling Group
- **Load Balancing**: Application Load Balancer (ALB)
- **Frontend**: S3 + CloudFront CDN
- **Seguridad**: Security Groups, WAF, Cognito, IAM
- **Base de Datos**: Amazon Aurora (RDS)
- **Caching**: ElastiCache (Redis)
- **Mensajería**: SNS + SQS
- **Procesamiento**: Lambda (consumidor de SQS)
- **Protección Web**: WAF (Web Application Firewall)
- **DNS**: Route53

### Características de Seguridad
✅ **WAF en CloudFront y ALB** - Protección contra ataques OWASP Top 10  
✅ **Encriptación** - SSE en SQS, EBS, RDS  
✅ **VPC Endpoints** - Acceso privado a AWS services  
✅ **Security Groups** - Control granular de tráfico  
✅ **IAM Roles** - Principio de menor privilegio  
✅ **Checkov** - Validación continua de seguridad  

---

## 🚀 Requisitos Previos

### Instalaciones Necesarias

1. **Terraform** (>= 1.0)
   ```bash
   brew install terraform        # macOS
   sudo apt install terraform    # Linux
   terraform --version
   ```

2. **AWS CLI**
   ```bash
   aws --version
   aws sts get-caller-identity
   ```

3. **Checkov** (validación seguridad)
   ```bash
   pip install checkov
   checkov --version
   ```

### Configuración AWS

```bash
aws configure
# AWS Access Key ID: ***
# AWS Secret Access Key: ***
# Default region name: us-east-1
# Default output format: json
```

---

## 📁 Estructura del Proyecto

```
IAC/
├── variables.tf, locals.tf    # Variables y workspace config
├── provider.tf, versions.tf   # AWS provider
├── vpc.tf, subnets.tf         # Networking
├── security_groups.tf         # SG (+ Lambda y Redis)
├── alb.tf, asg.tf             # Load balancing
├── s3_frontend.tf, cloudfront.tf # Frontend
├── aurora.tf, elasticache.tf  # Bases de datos
├── iam.tf, cognito.tf         # IAM y Auth
├── messaging.tf               # SNS + SQS (NUEVO)
├── lambda.tf                  # Lambda + EventSourceMapping (NUEVO)
├── lambda/index.py            # Código Python Lambda
├── waf.tf                     # WAF CloudFront + ALB (NUEVO)
├── dns.tf                     # Route53 (NUEVO)
├── outputs.tf                 # Outputs (NUEVO)
├── checkov_scan.sh            # Script seguridad (NUEVO)
└── Readme.md
```

---

## 🔧 Flujo de Trabajo Terraform

### 1. Inicializar

```bash
cd ~/IAC
terraform init
```

### 2. Crear Workspaces

```bash
terraform workspace new dev
terraform workspace new test
terraform workspace new prod

terraform workspace select dev
terraform workspace show
```

### 3. Validar

```bash
terraform validate
terraform fmt -recursive
```

### 4. Planificar

```bash
terraform plan -out=tfplan
```

### 5. Aplicar

```bash
terraform apply
# O sin confirmación:
terraform apply tfplan
```

### 6. Ver Outputs

```bash
terraform output
terraform output alb_dns_name
terraform output sqs_queue_url
terraform output lambda_function_name
terraform output frontend_domain
terraform output api_domain
```

### 7. Destruir

```bash
terraform destroy
terraform destroy -auto-approve  # Sin confirmar
```

---

## 🛡️ Validación con Checkov

### Ejecutar Escaneo

```bash
chmod +x checkov_scan.sh
./checkov_scan.sh

# O directamente:
checkov -d . --framework terraform
```

### Escaneos Específicos

```bash
# Problemas críticos
checkov -d . --framework terraform --check CKV_AWS_1

# IAM
checkov -d . --framework terraform --check CKV_AWS_40

# Seguridad de red
checkov -d . --framework terraform --check CKV_AWS_24

# Generar reporte JSON
checkov -d . --framework terraform --output json --output-file-path report.json
```

---

## 📤 Flujo SNS → SQS → Lambda

### Arquitectura

```
EC2 Instance → SNS Topic → SQS Queue → Lambda → CloudWatch Logs
                                          ↓
                                        DLQ (en fallo)
```

### Ejemplo: Publicar a SNS

```bash
# Conectar a instancia EC2
aws ssm start-session --target i-xxxxx --region us-east-1

# Publicar mensaje
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789012:iac-dev-app-events \
  --message '{"type": "user.created", "payload": {"user_id": "123", "email": "user@example.com"}}'
```

### Verificar SQS

```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/iac-dev-message-queue
```

### Ver Logs Lambda

```bash
# En tiempo real
aws logs tail /aws/lambda/iac-dev-message-processor --follow

# Últimas líneas
aws logs tail /aws/lambda/iac-dev-message-processor --max-items 50
```

### Personalizar Lambda

Edita `lambda/index.py`, modifica `process_message()`:

```bash
terraform apply  # Redeploy
```

---

## 🌐 DNS (Route53)

### Prerequisito: Hosted Zone

```bash
aws route53 list-hosted-zones
```

### Actualizar Variables

Edita `variables.tf`:

```hcl
variable "hosted_zone_name" {
  default = "tu-dominio.com"
}
variable "frontend_domain" {
  default = "app.tu-dominio.com"
}
variable "api_domain" {
  default = "api.tu-dominio.com"
}
```

### Aplicar y Verificar

```bash
terraform apply

terraform output frontend_domain
terraform output api_domain

# Esperar 5-10 min para DNS
nslookup app.tu-dominio.com
nslookup api.tu-dominio.com
```

---

## 🔒 WAF

### Características

**CloudFront WAF**:
- AWSManagedRulesCommonRuleSet (OWASP Top 10)
- Known Bad Inputs
- SQL Injection Protection
- Rate Limiting (2000 req/5 min)

**ALB WAF**:
- AWSManagedRulesCommonRuleSet
- SQL Injection Protection
- Rate Limiting (1000 req/5 min)

### Monitorear

```bash
# CloudFront WAF logs
aws logs tail /aws/waf/iac-dev-cloudfront --follow

# ALB WAF logs
aws logs tail /aws/waf/iac-dev-alb --follow

# Métricas
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=iac-dev-alb-waf \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

---

## 📊 Outputs Principales

```bash
terraform output alb_dns_name          # DNS ALB
terraform output sqs_queue_url         # URL SQS
terraform output lambda_function_name  # Lambda
terraform output frontend_domain       # Frontend domain
terraform output api_domain            # API domain
terraform output sns_topic_arn         # SNS Topic
```

---

## 🔐 Variables Sensibles

### terraform.tfvars

```hcl
redis_auth_token = "Tu-Token-De-16-Caracteres-O-Mas"
hosted_zone_name = "example.com"
frontend_domain  = "app.example.com"
api_domain       = "api.example.com"
region           = "us-east-1"
project_name     = "iac"
```

### Uso

```bash
terraform apply -var-file="terraform.tfvars"
```

### Proteger

```bash
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
```

---

## 🐛 Troubleshooting

### Error: "aws_sns_topic not found"

```bash
terraform init
terraform plan
```

### Error: "WebACL not found"

```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Lambda no procesa mensajes

```bash
# Verificar Lambda
aws lambda get-function --function-name iac-dev-message-processor

# Event mappings
aws lambda list-event-source-mappings \
  --function-name iac-dev-message-processor

# Mensajes en SQS
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names ApproximateNumberOfMessages

# Logs
aws logs tail /aws/lambda/iac-dev-message-processor --follow
```

### DNS no resuelve

```bash
dig api.tu-dominio.com
nslookup app.tu-dominio.com

# Revisar registros
aws route53 list-resource-record-sets \
  --hosted-zone-id Z123456789ABC
```

---

## 📝 Checklist

- [ ] Instalar Terraform, AWS CLI, Checkov
- [ ] Configurar AWS credentials
- [ ] `terraform init`
- [ ] Actualizar `variables.tf`
- [ ] `terraform plan`
- [ ] `terraform apply`
- [ ] `checkov_scan.sh`
- [ ] `terraform output`
- [ ] Probar SNS → SQS → Lambda
- [ ] Verificar DNS
- [ ] Monitorear WAF
- [ ] Commit a Git

---

## 🔄 CI/CD (GitHub Actions)

```yaml
name: Terraform

on:
  push:
    branches: [develop]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      
      - run: terraform init
      - run: terraform validate
      - run: terraform plan -var-file="dev.tfvars" -out=tfplan
      - run: pip install checkov && checkov -d . --framework terraform
      - run: terraform apply tfplan
```

---

## 📚 Referencias

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Checkov Docs](https://www.checkov.io/)
- [AWS WAF](https://docs.aws.amazon.com/waf/)
- [Route53](https://docs.aws.amazon.com/route53/)

---

**Última actualización**: 11 de febrero de 2026  
**Estado**: ✅ Producción-ready
