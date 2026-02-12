# Variables para SNS/SQS/Lambda Messaging
# SQS Variables

variable "sqs_delay_seconds" {
  description = "Delay de entrega de mensajes en SQS (segundos)"
  type        = number
  default     = 0
}

variable "sqs_max_message_size" {
  description = "Tamaño máximo de mensaje en SQS (bytes)"
  type        = number
  default     = 262144 # 256 KB
}

variable "sqs_message_retention_seconds" {
  description = "Tiempo de retención de mensajes en la cola principal (segundos)"
  type        = number
  default     = 345600 # 4 días
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout para que Lambda procese mensajes (segundos)"
  type        = number
  default     = 300 # 5 minutos
}

variable "sqs_receive_wait_time_seconds" {
  description = "Long polling wait time (segundos)"
  type        = number
  default     = 20
}

variable "sqs_max_receive_count" {
  description = "Intentos máximos antes de enviar a DLQ"
  type        = number
  default     = 3
}

variable "sqs_dlq_retention_seconds" {
  description = "Tiempo de retención en DLQ (segundos)"
  type        = number
  default     = 1209600 # 14 días
}

# Lambda Variables

variable "lambda_runtime" {
  description = "Runtime de Python para Lambda"
  type        = string
  default     = "python3.11"
  
  validation {
    condition     = can(regex("^python3\\.(9|10|11|12)$", var.lambda_runtime))
    error_message = "Lambda runtime debe ser python3.9 o superior"
  }
}

variable "lambda_timeout" {
  description = "Timeout para ejecución de Lambda (segundos)"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Memoria asignada a Lambda (MB)"
  type        = number
  default     = 512

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Memory debe estar entre 128 MB y 10240 MB"
  }
}

variable "lambda_batch_size" {
  description = "Cantidad de mensajes a procesar en un batch"
  type        = number
  default     = 10
}

variable "lambda_batching_window" {
  description = "Ventana de batching en segundos"
  type        = number
  default     = 5
}

variable "lambda_log_level" {
  description = "Nivel de log para Lambda (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.lambda_log_level)
    error_message = "Log level debe ser DEBUG, INFO, WARNING o ERROR"
  }
}

variable "lambda_log_retention_days" {
  description = "Días de retención para CloudWatch Logs"
  type        = number
  default     = 30
}

# SNS Variables

variable "sns_display_name" {
  description = "Nombre visible del topic SNS"
  type        = string
  default     = "IAC Application Events"
}

# CloudWatch Alarms Variables

variable "dlq_alarm_threshold" {
  description = "Threshold de mensajes en DLQ para activar alarma"
  type        = number
  default     = 10
}

variable "queue_depth_alarm_threshold" {
  description = "Threshold de mensajes acumulados en cola principal"
  type        = number
  default     = 100
}

# Escalabilidad - Configuración avanzada

variable "enable_encryption" {
  description = "Habilitar encriptación en SNS y SQS"
  type        = bool
  default     = true
}

variable "enable_fifo_queue" {
  description = "Usar SQS FIFO para mantener orden de mensajes (experimental)"
  type        = bool
  default     = false
}

variable "lambda_reserved_concurrency" {
  description = "Concurrencia reservada para Lambda (0 = sin reserva)"
  type        = number
  default     = 0

  validation {
    condition     = var.lambda_reserved_concurrency >= 0
    error_message = "Reserved concurrency debe ser >= 0"
  }
}

variable "enable_lambda_provisioned_concurrency" {
  description = "Habilitar concurrencia aprovisionada (requiere pago adicional)"
  type        = bool
  default     = false
}

variable "tags_messaging" {
  description = "Tags adicionales para recursos de mensajería"
  type        = map(string)
  default = {
    Component = "Messaging"
    Feature   = "EventProcessing"
  }
}
