resource "aws_cloudwatch_log_group" "test_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.test_lambda.function_name}"
  retention_in_days = 30
}

resource "aws_iam_policy" "test_lambda_logging_policy" {
  name = "AccessKeyTestLambdaLoggingPolicy"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.test_cloudwatch_log_group.name}:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "test_lambda_policy" {
  name = "AccessKeyTestLambdaPolicy"
  path = "/"
  description = "Allows access to get a secrets manager secret"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "${aws_secretsmanager_secret.rotatable_secret.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_test_logger" {
  role = "${aws_iam_role.test_lambda_role.name}"
  policy_arn = "${aws_iam_policy.test_lambda_logging_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_test" {
  role = "${aws_iam_role.test_lambda_role.name}"
  policy_arn = "${aws_iam_policy.test_lambda_policy.arn}"
}

resource "aws_iam_role" "test_lambda_role" {
  name = "TestAccessKeyLambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "allow_secret_manager_call_test_lambda" {
  function_name = "${aws_lambda_function.test_lambda.function_name}"
  statement_id = "AllowExecutionFromSecretsManager"
  action = "lambda:InvokeFunction"
  principal = "secretsmanager.amazonaws.com"
}

resource "aws_lambda_function" "test_lambda" {
  filename         = "../test-lambda.zip"
  function_name    = "testAccessKey"
  role             = "${aws_iam_role.test_lambda_role.arn}"
  handler          = "test-lambda"
  source_code_hash = "${filebase64sha256("../test-lambda.zip")}"
  runtime          = "go1.x"
}

resource "aws_cloudwatch_event_rule" "every_1_hour" {
    name = "every_1_hour"
    description = "Fires every 1 hour"
    schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "test_rotated_keys_every_1_hour" {
    rule = "${aws_cloudwatch_event_rule.every_1_hour.name}"
    target_id = "test_lambda"
    arn = "${aws_lambda_function.test_lambda.arn}"
    input = <<DOC
{
  "SecretId": "${aws_secretsmanager_secret.rotatable_secret.id}"
}
DOC
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_test_rotated_keys" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.test_lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_1_hour.arn}"
}
