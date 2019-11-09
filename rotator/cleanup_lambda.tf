data "archive_file" "cleanup_lambda_zip" {
  type        = "zip"
  source_file = "../build/cleanup-lambda"
  output_path = "../build/cleanup-lambda.zip"
}

resource "aws_lambda_function" "cleanup_lambda" {
  filename         = "../build/cleanup-lambda.zip"
  function_name    = "cleanupAccessKey"
  handler          = "cleanup-lambda"
  role             = aws_iam_role.cleanup_lambda_role.arn
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256
  runtime          = "go1.x"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_cleanup_rotated_keys" {
  function_name = aws_lambda_function.cleanup_lambda.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_rule.arn
}

resource "aws_cloudwatch_event_rule" "cleanup_rule" {
  name                = "cleanup_rule"
  description         = "Fires every ${var.cleanup_lambda_run_rate}"
  schedule_expression = "rate(${var.cleanup_lambda_run_rate})"
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  target_id = "cleanup_lambda"
  rule      = aws_cloudwatch_event_rule.cleanup_rule.name
  arn       = aws_lambda_function.cleanup_lambda.arn
}

resource "aws_cloudwatch_log_group" "cleanup_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.cleanup_lambda.function_name}"
  retention_in_days = var.cloudwatch_retention_days
}
