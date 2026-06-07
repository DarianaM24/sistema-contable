variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (usado como prefijo en todos los recursos)"
  type        = string
  default     = "sistema-contable"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "prod"
}

variable "database_url" {
  description = "URL de conexión a la base de datos PostgreSQL (Neon/Supabase/RDS)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secreto para firmar los tokens JWT"
  type        = string
  sensitive   = true
}

variable "lambda_zip_path" {
  description = "Ruta al archivo ZIP del binario compilado de Go"
  type        = string
  default     = "../lambda.zip"
}
