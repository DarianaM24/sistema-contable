output "api_gateway_url" {
  description = "URL pública del API Gateway — úsala en tu app móvil"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda desplegada"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.api.arn
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "s3_bucket_url" {
  description = "URL base del bucket S3"
  value       = "https://${aws_s3_bucket.uploads.bucket}.s3.${var.aws_region}.amazonaws.com"
}

output "cloudwatch_log_group" {
  description = "Grupo de logs en CloudWatch"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
