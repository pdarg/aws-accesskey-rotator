resource "aws_cloudwatch_log_group" "rotate_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.rotate_lambda.function_name}"
  retention_in_days = 30
}

resource "aws_iam_policy" "rotator_lambda_logging_policy" {
  name = "AccessKeyRotatorLambdaLoggingPolicy"
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
      "Resource": "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.rotate_cloudwatch_log_group.name}:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "rotator_lambda_policy" {
  name = "AccessKeyRotatorLambdaPolicy"
  path = "/"
  description = "Allows access to get and update secrets manager secret and create new IAM access keys"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ],
      "Resource": "${aws_secretsmanager_secret.rotatable_secret.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:ListAccessKeys"
      ],
      "Resource": "${aws_iam_user.app_bot.arn}"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logger" {
  role = "${aws_iam_role.rotate_lambda_role.name}"
  policy_arn = "${aws_iam_policy.rotator_lambda_logging_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_rotater" {
  role = "${aws_iam_role.rotate_lambda_role.name}"
  policy_arn = "${aws_iam_policy.rotator_lambda_policy.arn}"
}

resource "aws_iam_role" "rotate_lambda_role" {
  name = "RotateAccessKeyLambdaRole"

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

resource "aws_lambda_permission" "allow_secret_manager_call_rotate_lambda" {
  function_name = "${aws_lambda_function.rotate_lambda.function_name}"
  statement_id = "AllowExecutionFromSecretsManager"
  action = "lambda:InvokeFunction"
  principal = "secretsmanager.amazonaws.com"
}

resource "aws_lambda_function" "rotate_lambda" {
  filename         = "../rotate-lambda.zip"
  function_name    = "rotateAccessKey"
  role             = "${aws_iam_role.rotate_lambda_role.arn}"
  handler          = "rotate-lambda"
  source_code_hash = "${filebase64sha256("../rotate-lambda.zip")}"
  runtime          = "go1.x"
}
