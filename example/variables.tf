variable "user_name" {
  type        = string
  description = "Name for user"
  default     = "app-bot"
}

variable "user_name1" {
  type        = string
  description = "Name for user1"
  default     = "app-bot1"
}

variable "secret_name" {
  type        = string
  description = "Name for secret"
  default     = "dev/app-bot-key"
}

variable "secret_name1" {
  type        = string
  description = "Name for secret1"
  default     = "dev/app-bot1-key"
}

variable "test_bucket" {
  type        = string
  description = "Test S3 bucket"
  default     = "app-bot-test-bucket"
}

variable "test_object" {
  type        = string
  description = "Test S3 object name"
  default     = "test"
}

variable "tester_lambda_run_rate" {
  type        = string
  description = "Frequency to run the tester lambda (as a CloudWatch Event Rule rate value)"
  default     = "1 hour"
}

variable "rotate_after_days" {
  type        = number
  description = "Frequency to run rotate lambda (in days)"
  default     = 30
}

variable "cloudwatch_retention_days" {
  type        = number
  description = "Number of days to keep rotate cloudwatch logs"
  default     = 30
}

variable "default_tags" {
  type        = map
  description = "Additional tags to apply to users and secrets"
  default = {
    Name : "DemoRotatableUser"
    Description : "Example Rotatable Bot with Access Keys",
    Env : "dev",
  }
}
