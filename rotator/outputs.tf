output "rotator_lambda_arn" {
  value       = aws_lambda_function.rotate_lambda.arn
  description = "The arn of the rotation lambda"
}
