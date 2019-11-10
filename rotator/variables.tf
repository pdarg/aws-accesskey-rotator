variable "cloudwatch_retention_days" {
  type        = number
  description = "Number of days to keep rotate cloudwatch logs"
  default     = 30
}

variable "cleanup_lambda_run_rate" {
  type        = string
  description = "Frequency to run the cleanup lambda (as a CloudWatch Event Rule rate value)"
  default     = "24 hours"
}
