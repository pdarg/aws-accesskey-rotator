# User variables

variable "user_name" {
  type        = string
  description = "Name for user"
}

variable "user_path" {
  type        = string
  description = "Path setting for user"
  default     = "/"
}

variable "user_permissions_boundary" {
  type        = string
  description = "Arn of permissions_boundary for user"
  default     = null
}

variable "user_force_destroy" {
  type        = bool
  description = "force_destroy setting for user"
  default     = null
}

variable "user_tags" {
  type        = map
  description = "Additional tags to apply to users"
  default     = {}
}

# Secret variables

variable "secret_name" {
  type        = string
  description = "Name for secret that will hold the user's access key/secret"
}

variable "secret_description" {
  type        = string
  description = "description setting for secret"
  default     = ""
}

variable "secret_kms_key_id" {
  type        = string
  description = "KMS key arn or alis for encrypting the secret"
  default     = null
}

variable "secret_name_prefix" {
  type        = string
  description = "name_prefix setting for secret"
  default     = null
}

variable "secret_policy" {
  type        = string
  description = "policy json for secret"
  default     = null
}

variable "secret_recovery_window_in_days" {
  type        = number
  description = "recovery_window_in_days setting for secret"
  default     = null
}

variable "secret_tags" {
  type        = map
  description = "Additional tags to apply to secrets"
  default     = {}
}

# Rotation variables

variable "rotator_lambda_arn" {
  type        = string
  description = "Arn of the lambda function responsible for rotation"
}

variable "rotate_after_days" {
  type        = number
  description = "Frequency to run rotate lambda (in days)"
  default     = 30
}
