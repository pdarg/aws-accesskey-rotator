output "user_arn" {
  value       = aws_iam_user.rotatable_user.arn
  description = "The IAM user arn"
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.rotatable_secret.arn
  description = "The secret arn"
}
