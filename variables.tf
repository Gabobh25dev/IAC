variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "iac"
}

variable "region" {
  description = "RegiÃ³n AWS"
  type        = string
  default     = "us-east-1"
}

variable "hosted_zone_name" {
  description = "Nombre de la hosted zone existente en Route53 (ej: example.com)"
  type        = string
  default     = "example.com"
}

variable "frontend_domain" {
  description = "Dominio para el frontend (ej: app.example.com)"
  type        = string
  default     = "app.example.com"
}

variable "api_domain" {
  description = "Dominio para el API/ALB (ej: api.example.com)"
  type        = string
  default     = "api.example.com"
}

variable "sqs_message_retention_seconds" {
  description = "RetenciÃ³n de mensajes en SQS (segundos)"
  type        = number
  default     = 345600 # 4 dÃ­as
}

variable "lambda_timeout" {
  description = "Timeout de Lambda en segundos"
  type        = number
  default     = 60
}

variable "lambda_memory" {
  description = "Memoria de Lambda en MB"
  type        = number
  default     = 256
}
