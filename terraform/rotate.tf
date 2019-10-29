resource "aws_cloudwatch_log_group" "rotate_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.rotate_lambda.function_name}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "rotator_lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.rotate_cloudwatch_log_group.name}:*",
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
    ]

    resources = [
      "arn:aws:secretsmanager:*:*:secret:*",
    ]

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:ResourceTag/Rotatable"

      values = [
        true,
      ]
    }
  }

  statement {
    actions = [
      "iam:CreateAccessKey",
    ]

    resources = [
      "arn:aws:iam::*:user/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:ResourceTag/Rotatable"

      values = [
        true,
      ]
    }
  }
}

data "aws_iam_policy_document" "rotator_lambda_role_document" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "rotator_lambda_policy" {
  name        = "RotateAccessKeyLambdaPolicy"
  path        = "/"
  description = "Allows access to get and update secrets manager secret and create new IAM access keys, and logging from a lambda"
  policy      = "${data.aws_iam_policy_document.rotator_lambda_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "lambda_rotater" {
  role       = "${aws_iam_role.rotate_lambda_role.name}"
  policy_arn = "${aws_iam_policy.rotator_lambda_policy.arn}"
}

resource "aws_iam_role" "rotate_lambda_role" {
  name               = "RotateAccessKeyLambdaRole"
  assume_role_policy = "${data.aws_iam_policy_document.rotator_lambda_role_document.json}"
}

resource "aws_lambda_permission" "allow_secret_manager_call_rotate_lambda" {
  function_name = "${aws_lambda_function.rotate_lambda.function_name}"
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  principal     = "secretsmanager.amazonaws.com"
}

data "archive_file" "rotate_lambda_zip" {
  type        = "zip"
  source_file = "../build/rotate-lambda"
  output_path = "../build/rotate-lambda.zip"
}

resource "aws_lambda_function" "rotate_lambda" {
  filename         = "../build/rotate-lambda.zip"
  function_name    = "rotateAccessKey"
  role             = "${aws_iam_role.rotate_lambda_role.arn}"
  handler          = "rotate-lambda"
  source_code_hash = "${data.archive_file.rotate_lambda_zip.output_base64sha256}"
  runtime          = "go1.x"
}
