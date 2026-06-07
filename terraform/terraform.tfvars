# ⚠️  NO subas este archivo si contiene credenciales reales.
#     Los valores sensibles (database_url, jwt_secret) se inyectan
#     como GitHub Secrets en el pipeline de CI/CD.

aws_region      = "us-east-1"
project_name    = "sistema-contable"
environment     = "prod"
lambda_zip_path = "../lambda.zip"

# Estos valores se sobreescriben en el pipeline con -var flags:
# database_url = "postgresql://user:pass@host/db?sslmode=require"
# jwt_secret   = "mi_secreto_super_seguro"
