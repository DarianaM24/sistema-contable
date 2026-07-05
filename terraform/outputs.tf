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

output "sns_topic_arn" {
  description = "ARN del topic SNS de notificaciones"
  value       = aws_sns_topic.notifications.arn
}

output "sqs_queue_url" {
  description = "URL de la cola SQS de notificaciones"
  value       = aws_sqs_queue.notifications.url
}

output "notification_lambda_name" {
  description = "Nombre de la Lambda de notificaciones"
  value       = aws_lambda_function.notification.function_name
}

output "scheduler_schedule_name" {
  description = "Nombre de la tarea programada de EventBridge Scheduler"
  value       = aws_scheduler_schedule.heartbeat_notification.name
}

output "scheduler_schedule_arn" {
  description = "ARN de la tarea programada de EventBridge Scheduler"
  value       = aws_scheduler_schedule.heartbeat_notification.arn
}

output "scheduler_expression" {
  description = "Expresion rate/cron utilizada por el schedule"
  value       = aws_scheduler_schedule.heartbeat_notification.schedule_expression
}

output "heartbeat_lambda_name" {
  description = "Nombre de la Lambda invocada por el EventBridge Scheduler"
  value       = aws_lambda_function.heartbeat.function_name
}

output "heartbeat_lambda_log_group" {
  description = "Grupo de logs en CloudWatch de la Lambda de heartbeat"
  value       = aws_cloudwatch_log_group.heartbeat_lambda_logs.name
}