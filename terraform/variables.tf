variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "sistema-contable"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "prod"
}

variable "jwt_secret" {
  description = "Secreto JWT"
  type        = string
  sensitive   = true
}

variable "lambda_zip_path" {
  description = "Ruta al ZIP de la Lambda"
  type        = string
  default     = "../lambda.zip"
}

variable "db_host" {
  description = "Host de la base de datos"
  type        = string
}

variable "db_port" {
  description = "Puerto de la base de datos"
  type        = string
  default     = "5432"
}

variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "notification_email" {
  description = "Email verificado en AWS SES que enviará los correos"
  type        = string
}

variable "notification_lambda_zip_path" {
  description = "Ruta al ZIP de la Lambda de notificaciones"
  type        = string
  default     = "../notification-lambda.zip"
}

variable "heartbeat_lambda_zip_path" {
  description = "Ruta al ZIP de la Lambda de heartbeat (EventBridge Scheduler)"
  type        = string
  default     = "../heartbeat-lambda.zip"
}