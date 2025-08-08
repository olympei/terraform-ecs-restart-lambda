
output "lambda_function_name" {
  value = aws_lambda_function.ecs_restart.function_name
}

output "log_group_name" {
  value = local.log_group_name
}
