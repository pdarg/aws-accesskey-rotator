variable "user_name" {
  type        = string
  description = "Name for user"
}

variable "secret_name" {
  type        = string
  description = "Name for secret that will hold the user's access key/secret"
}

variable "rotator_lambda_arn" {
  type        = string
  description = "Arn of the lambda function responsible for rotation"
}

variable "user_tags" {
  type        = map
  description = "Additional tags to apply to users"
  default     = {}
}

variable "secret_tags" {
  type        = map
  description = "Additional tags to apply to secrets"
  default     = {}
}

variable "rotate_after_days" {
  type        = number
  description = "Frequency to run rotate lambda (in days)"
  default     = 30
}
