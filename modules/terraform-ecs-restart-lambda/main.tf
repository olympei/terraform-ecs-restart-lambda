
provider "aws" {
  region = var.region
}

resource "aws_kms_key" "log_group_key" {
  count               = var.kms_key_id == "" && !var.use_existing_log_group ? 1 : 0
  description         = "KMS key for encrypting Lambda log group"
  deletion_window_in_days = 7
  enable_key_rotation = true
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/restart_ecs.py"
  output_path = "${path.module}/lambda/restart_ecs.zip"
}

resource "aws_lambda_function" "ecs_restart" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "restart_ecs.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      ECS_CLUSTER  = var.ecs_cluster
      ECS_SERVICES = jsonencode(var.ecs_services)
    }
  }


}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  count             = var.use_existing_log_group ? 0 : 1
  name              = "/aws/lambda/custom/${aws_lambda_function.ecs_restart.function_name}"
  retention_in_days = var.log_group_retention

  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : (length(aws_kms_key.log_group_key) > 0 ? aws_kms_key.log_group_key[0].arn : null)

  tags = {
    Name        = "LambdaCustomLogGroup"
    Environment = var.lambda_function_name
  }
}

data "aws_arn" "log_group" {
  count = var.use_existing_log_group ? 1 : 0
  arn   = var.existing_log_group_arn
}

locals {
  log_group_name = var.use_existing_log_group ? replace(data.aws_arn.log_group[0].resource, "log-group:", "") : aws_cloudwatch_log_group.lambda_logs[0].name
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_function_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.lambda_function_name}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ecs:UpdateService", "ecs:DescribeServices"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:log-group:${local.log_group_name}:*"
      },
      {
        Effect = "Allow",
        Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"],
        Resource = var.kms_key_id != "" ? var.kms_key_id : (length(aws_kms_key.log_group_key) > 0 ? aws_kms_key.log_group_key[0].arn : "*")
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_cloudwatch_event_rule" "ecs_restart" {
  name                = "${var.lambda_function_name}-event"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "ecs_restart" {
  rule      = aws_cloudwatch_event_rule.ecs_restart.name
  target_id = "lambda-restart"
  arn       = aws_lambda_function.ecs_restart.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_restart.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_restart.arn
}
