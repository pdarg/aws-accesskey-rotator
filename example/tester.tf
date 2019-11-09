data "archive_file" "tester_lambda_zip" {
  type        = "zip"
  source_file = "tester-lambda"
  output_path = "tester-lambda.zip"
}

resource "aws_lambda_function" "tester_lambda" {
  filename         = "tester-lambda.zip"
  function_name    = "testAccessKey"
  role             = aws_iam_role.tester_lambda_role.arn
  handler          = "tester-lambda"
  source_code_hash = data.archive_file.tester_lambda_zip.output_base64sha256
  runtime          = "go1.x"

  environment {
    variables = {
      TEST_BUCKET = var.test_bucket
      TEST_OBJECT = var.test_object
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_test_rotated_keys" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tester_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tester_rule.arn
}

resource "aws_cloudwatch_event_rule" "tester_rule" {
  name                = "tester_rule"
  description         = "Fires every ${var.tester_lambda_run_rate}"
  schedule_expression = "rate(${var.tester_lambda_run_rate})"
}

resource "aws_cloudwatch_event_target" "tester_target" {
  target_id = "tester_lambda"
  rule      = aws_cloudwatch_event_rule.tester_rule.name
  arn       = aws_lambda_function.tester_lambda.arn
}

resource "aws_cloudwatch_log_group" "test_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.tester_lambda.function_name}"
  retention_in_days = var.cloudwatch_retention_days
}
