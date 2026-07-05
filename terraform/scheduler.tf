# ============================================================
# EventBridge Scheduler — tarea programada cada 5 minutos
# ============================================================
# Objetivo: invocar directamente una Lambda dedicada
# ("heartbeat") cada 5 minutos, la cual únicamente registra el
# evento en CloudWatch Logs. Esta Lambda es independiente de la
# Lambda de notificaciones de producción (que envía correos
# reales vía SES), para no interferir con el flujo de negocio.
#
# Flujo completo:
#   EventBridge Scheduler --(rate(5 minutes))--> Lambda "heartbeat"
#     --> CloudWatch Logs
# ============================================================

# --------------------------------------------------------------
# IAM Role que EventBridge Scheduler asume para invocar el target
# --------------------------------------------------------------
resource "aws_iam_role" "scheduler_role" {
  name = "${var.project_name}-scheduler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Permiso: el rol del Scheduler solo puede invocar la Lambda de heartbeat
resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "${var.project_name}-scheduler-lambda-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.heartbeat.arn
    }]
  })
}

# --------------------------------------------------------------
# IAM Role de ejecución de la Lambda de heartbeat
# --------------------------------------------------------------
resource "aws_iam_role" "heartbeat_lambda_role" {
  name = "${var.project_name}-heartbeat-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "heartbeat_lambda_basic" {
  role       = aws_iam_role.heartbeat_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------------------------------------------
# CloudWatch — Grupo de logs para la Lambda de heartbeat
# --------------------------------------------------------------
resource "aws_cloudwatch_log_group" "heartbeat_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-heartbeat-${var.environment}"
  retention_in_days = 14

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --------------------------------------------------------------
# Lambda — solo registra el evento en CloudWatch Logs
# --------------------------------------------------------------
resource "aws_lambda_function" "heartbeat" {
  function_name    = "${var.project_name}-heartbeat-${var.environment}"
  description      = "Lambda invocada por EventBridge Scheduler cada 5 min; registra el evento en CloudWatch Logs"
  filename         = var.heartbeat_lambda_zip_path
  source_code_hash = filebase64sha256(var.heartbeat_lambda_zip_path)
  runtime          = "provided.al2023"
  handler          = "bootstrap"
  role             = aws_iam_role.heartbeat_lambda_role.arn
  timeout          = 10
  memory_size      = 128

  depends_on = [
    aws_iam_role_policy_attachment.heartbeat_lambda_basic,
    aws_cloudwatch_log_group.heartbeat_lambda_logs,
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Permiso para que EventBridge Scheduler invoque esta Lambda
resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowEventBridgeSchedulerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.heartbeat.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.heartbeat_notification.arn
}

# --------------------------------------------------------------
# Schedule Group (opcional pero recomendado para organizar)
# --------------------------------------------------------------
resource "aws_scheduler_schedule_group" "main" {
  name = "${var.project_name}-schedules-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --------------------------------------------------------------
# Schedule — se ejecuta cada 5 minutos
# --------------------------------------------------------------
resource "aws_scheduler_schedule" "heartbeat_notification" {
  name       = "${var.project_name}-heartbeat-${var.environment}"
  group_name = aws_scheduler_schedule_group.main.name

  description = "Invoca la Lambda de heartbeat cada 5 minutos (Sistema Contable)"

  # Expresión rate: cada 5 minutos
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "America/Santo_Domingo"

  state = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.heartbeat.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      origen  = "EventBridge Scheduler"
      mensaje = "Heartbeat automatico del Sistema Contable - verificacion cada 5 minutos"
      tipo    = "SCHEDULED_HEARTBEAT"
    })

    # Reintentos en caso de fallo al invocar el target
    retry_policy {
      maximum_event_age_in_seconds = 300
      maximum_retry_attempts       = 2
    }
  }
}
