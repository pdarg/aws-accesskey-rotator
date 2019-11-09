data "archive_file" "rotate_lambda_zip" {
  type        = "zip"
  source_file = "../build/rotate-lambda"
  output_path = "../build/rotate-lambda.zip"
}

resource "aws_lambda_function" "rotate_lambda" {
  filename         = "../build/rotate-lambda.zip"
  function_name    = "rotateAccessKey"
  handler          = "rotate-lambda"
  role             = aws_iam_role.rotate_lambda_role.arn
  source_code_hash = data.archive_file.rotate_lambda_zip.output_base64sha256
  runtime          = "go1.x"
}

resource "aws_lambda_permission" "allow_secret_manager_call_rotate_lambda" {
  function_name = aws_lambda_function.rotate_lambda.function_name
  action        = "lambda:InvokeFunction"
  principal     = "secretsmanager.amazonaws.com"
}

resource "aws_cloudwatch_log_group" "rotate_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.rotate_lambda.function_name}"
  retention_in_days = var.cloudwatch_retention_days
}
