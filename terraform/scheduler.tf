# ============================================================
# EventBridge Scheduler — tarea programada cada 5 minutos
# ============================================================
# Objetivo: publicar un mensaje en el tópico SNS "notifications"
# cada 5 minutos. Ese mensaje ya está suscrito por la cola SQS
# "notifications", que a su vez dispara la Lambda de
# notificaciones (aws_lambda_function.notification), la cual
# registra el evento en CloudWatch Logs.
#
# Flujo completo:
#   EventBridge Scheduler --(rate(5 minutes))--> SNS Topic
#     --> SQS Queue --> Lambda "notification" --> CloudWatch Logs
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

# Permiso: el rol del Scheduler solo puede publicar en el tópico SNS
resource "aws_iam_role_policy" "scheduler_sns_publish" {
  name = "${var.project_name}-scheduler-sns-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.notifications.arn
    }]
  })
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

  description = "Publica un heartbeat en SNS cada 5 minutos (Sistema Contable)"

  # Expresión rate: cada 5 minutos
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "America/Santo_Domingo"

  state = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sns_topic.notifications.arn
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
