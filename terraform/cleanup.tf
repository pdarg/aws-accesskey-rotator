resource "aws_cloudwatch_log_group" "cleanup_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.cleanup_lambda.function_name}"
  retention_in_days = 30
}

resource "aws_iam_policy" "cleanup_lambda_logging_policy" {
  name = "AccessKeyCleanupLambdaLoggingPolicy"
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
      "Resource": "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cleanup_cloudwatch_log_group.name}:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cleanup_lambda_policy" {
  name = "AccessKeyCleanupLambdaPolicy"
  path = "/"
  description = "TODO: fill me in"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${aws_secretsmanager_secret.rotatable_secret.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:DeleteAccessKey",
        "iam:GetAccessKeyLastUsed",
        "iam:ListAccessKeys",
        "iam:UpdateAccessKey"
      ],
      "Resource": [
        "${aws_iam_user.app_bot.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_cleanup_logger" {
  role = "${aws_iam_role.cleanup_lambda_role.name}"
  policy_arn = "${aws_iam_policy.cleanup_lambda_logging_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_cleanup" {
  role = "${aws_iam_role.cleanup_lambda_role.name}"
  policy_arn = "${aws_iam_policy.cleanup_lambda_policy.arn}"
}

resource "aws_iam_role" "cleanup_lambda_role" {
  name = "CleanupAccessKeyLambdaRole"

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

resource "aws_lambda_permission" "allow_secret_manager_call_cleanup_lambda" {
  function_name = "${aws_lambda_function.cleanup_lambda.function_name}"
  statement_id = "AllowExecutionFromSecretsManager"
  action = "lambda:InvokeFunction"
  principal = "secretsmanager.amazonaws.com"
}

resource "aws_lambda_function" "cleanup_lambda" {
  filename         = "cleanup-lambda.zip"
  function_name    = "cleanupAccessKey"
  role             = "${aws_iam_role.cleanup_lambda_role.arn}"
  handler          = "cleanup-lambda"
  source_code_hash = "${filebase64sha256("../cleanup-lambda.zip")}"
  runtime          = "go1.x"
}

resource "aws_cloudwatch_event_rule" "every_24_hours" {
    name = "every_24_hours"
    description = "Fires every 24 hours"
    schedule_expression = "rate(24 hours)"
}

resource "aws_cloudwatch_event_target" "cleanup_rotated_keys_every_24_hours" {
    rule = "${aws_cloudwatch_event_rule.every_24_hours.name}"
    target_id = "cleanup_lambda"
    arn = "${aws_lambda_function.cleanup_lambda.arn}"
    input = <<DOC
{
  "SecretId": "${aws_secretsmanager_secret.rotatable_secret.id}"
}
DOC
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_cleanup_rotated_keys" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.cleanup_lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_24_hours.arn}"
}