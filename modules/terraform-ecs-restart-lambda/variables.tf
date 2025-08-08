
variable "region" {
  default = "us-east-1"
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "ecs_cluster" {
  description = "ECS Cluster Name"
  type        = string
}

variable "ecs_services" {
  description = "List of ECS services to restart"
  type        = list(string)
}

variable "schedule_expression" {
  description = "EventBridge CRON or rate schedule"
  type        = string
  default     = "cron(0 3 * * ? *)"
}

variable "use_existing_log_group" {
  type    = bool
  default = false
}

variable "existing_log_group_arn" {
  type    = string
  default = ""
}

variable "log_group_retention" {
  type    = number
  default = 14
}

variable "kms_key_id" {
  type    = string
  default = ""
}
