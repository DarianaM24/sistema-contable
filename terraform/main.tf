# ============================================================
# S3 — almacenamiento de archivos subidos (uploads)
# ============================================================
resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.project_name}-uploads-${var.environment}"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "uploads_public_read" {
  bucket     = aws_s3_bucket.uploads.id
  depends_on = [aws_s3_bucket_public_access_block.uploads]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

# ============================================================
# IAM — Rol que ejecutará la Lambda
# ============================================================
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role-${var.environment}"

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

# Política base: permite escribir logs en CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Política adicional: permite a la Lambda subir/leer archivos en S3
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

# ============================================================
# CloudWatch — Grupo de logs para la Lambda
# ============================================================
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}"
  retention_in_days = 14

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# Lambda Function — binario Go compilado para linux/amd64
# ============================================================
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}"
  description   = "API REST - Sistema Contable (Go + Gin)"

  # El handler para Go en Lambda debe llamarse "bootstrap" (runtime provided.al2023)
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  runtime = "provided.al2023" # Runtime custom para binarios Go
  handler = "bootstrap"       # Nombre del ejecutable dentro del ZIP

  role        = aws_iam_role.lambda_exec.arn
  timeout     = 30  # segundos
  memory_size = 256 # MB

environment {
    variables = {
      DB_HOST    = var.db_host
      DB_PORT    = var.db_port
      DB_USER    = var.db_user
      DB_PASSWORD = var.db_password
      DB_NAME    = var.db_name
      JWT_SECRET  = var.jwt_secret
      S3_BUCKET   = aws_s3_bucket.uploads.bucket
      S3_REGION   = var.aws_region
      GIN_MODE    = "release"
      SNS_TOPIC_ARN = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs,
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# API Gateway (HTTP API v2) — más barato y simple que REST API
# ============================================================
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API Gateway para Sistema Contable"

cors_configuration {
    allow_headers  = ["Content-Type", "Authorization", "X-Requested-With"]
    allow_methods  = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
    allow_origins  = ["*"]
    expose_headers = ["Content-Length"]
    max_age        = 300
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Integración: API Gateway → Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.api.invoke_arn
  integration_method = "POST"

  payload_format_version = "2.0"
}

# Ruta catch-all: redirige CUALQUIER método y ruta a la Lambda
resource "aws_apigatewayv2_route" "catch_all" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "options" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "OPTIONS /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage de despliegue (auto-deploy activo)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

access_log_settings {
    destination_arn = aws_cloudwatch_log_group.lambda_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      protocol       = "$context.protocol"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ============================================================
# SNS Topic — recibe mensajes del backend
# ============================================================
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-notifications-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# SQS Queue — recibe mensajes desde SNS
# ============================================================
resource "aws_sqs_queue" "notifications_dlq" {
  name = "${var.project_name}-notifications-dlq-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "notifications" {
  name                       = "${var.project_name}-notifications-${var.environment}"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# Suscripción SNS → SQS
# ============================================================
resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications.arn
}

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notifications.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn }
      }
    }]
  })
}

# ============================================================
# IAM — Rol para la Lambda de notificaciones
# ============================================================
resource "aws_iam_role" "notification_lambda_role" {
  name = "${var.project_name}-notification-role-${var.environment}"

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

resource "aws_iam_role_policy" "notification_lambda_policy" {
  name = "${var.project_name}-notification-policy-${var.environment}"
  role = aws_iam_role.notification_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.notifications.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

# Permiso para que la Lambda PRINCIPAL pueda publicar en SNS
resource "aws_iam_role_policy" "lambda_sns" {
  name = "${var.project_name}-lambda-sns-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.notifications.arn
    }]
  })
}

# ============================================================
# CloudWatch — Logs para la Lambda de notificaciones
# ============================================================
resource "aws_cloudwatch_log_group" "notification_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-notification-${var.environment}"
  retention_in_days = 14

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# Lambda de Notificaciones
# ============================================================
resource "aws_lambda_function" "notification" {
  function_name    = "${var.project_name}-notification-${var.environment}"
  description      = "Lambda que recibe SQS y envía correos con SES"
  filename         = var.notification_lambda_zip_path
  source_code_hash = filebase64sha256(var.notification_lambda_zip_path)
  runtime          = "provided.al2023"
  handler          = "bootstrap"
  role             = aws_iam_role.notification_lambda_role.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      FROM_EMAIL = var.notification_email
    }
  }

  depends_on = [
    aws_iam_role_policy.notification_lambda_policy,
    aws_cloudwatch_log_group.notification_lambda_logs,
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ============================================================
# Event Source Mapping — SQS activa la Lambda de notificaciones
# ============================================================
resource "aws_lambda_event_source_mapping" "sqs_to_notification" {
  event_source_arn = aws_sqs_queue.notifications.arn
  function_name    = aws_lambda_function.notification.arn
  batch_size       = 1
  enabled          = true
}