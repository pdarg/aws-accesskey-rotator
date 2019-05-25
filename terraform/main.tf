provider "aws" {
  region  = "us-west-2"
}

data "aws_caller_identity" "current" {}

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
  description = "TODO: fill me in"

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
      "Resource": [
        "${aws_secretsmanager_secret.rotatable_secret.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:ListAccessKeys"
      ],
      "Resource": [
        "${aws_iam_user.app_bot.arn}"
      ]
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
  filename         = "rotate-lambda.zip"
  function_name    = "rotateAccessKey"
  role             = "${aws_iam_role.rotate_lambda_role.arn}"
  handler          = "rotate-lambda"
  source_code_hash = "${filebase64sha256("rotate-lambda.zip")}"
  runtime          = "go1.x"
}

resource "aws_secretsmanager_secret" "rotatable_secret" {
  name                = "dev/rotatable-secret"
  rotation_lambda_arn = "${aws_lambda_function.rotate_lambda.arn}"

  rotation_rules {
    automatically_after_days = 7
  }
}

resource "aws_secretsmanager_secret_version" "rotatable_access_key" {
  secret_id     = "${aws_secretsmanager_secret.rotatable_secret.id}"
  secret_string = "${jsonencode({
    Key = "FAKEKEY"
    Secret = "FAKESECRET"
    UserName = "${aws_iam_user.app_bot.name}"
  })}"
  version_stages = ["AWSCURRENT"]

  lifecycle {
    ignore_changes = [
      version_stages,
    ]
  }
}

resource "aws_s3_bucket_object" "test_object" {
  bucket = "${aws_s3_bucket.key_test_bucket.id}"
  key    = "test"
  source = "../test"
  etag = "${filemd5("../test")}"
}

resource "aws_s3_bucket" "key_test_bucket" {
  bucket = "app-bot-test-bucket"
  acl    = "private"
}

resource "aws_iam_user_policy" "app_bot_test_data" {
  name = "GetPermissionTestData"
  user = "${aws_iam_user.app_bot.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "${aws_s3_bucket.key_test_bucket.arn}/test"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user" "app_bot" {
  name = "app-bot"
}