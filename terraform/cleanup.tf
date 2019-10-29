resource "aws_cloudwatch_log_group" "cleanup_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.cleanup_lambda.function_name}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "cleanup_lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cleanup_cloudwatch_log_group.name}:*",
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
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
      "secretsmanager:ListSecrets",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "iam:DeleteAccessKey",
      "iam:GetAccessKeyLastUsed",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
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

data "aws_iam_policy_document" "cleanup_lambda_role_document" {
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

resource "aws_iam_policy" "cleanup_lambda_policy" {
  name        = "CleanupAccessKeyLambdaPolicy"
  path        = "/"
  description = "Allows access to get a secret manager secret, and list, update, and delete IAM access keys, and logging from a lambda"
  policy      = "${data.aws_iam_policy_document.cleanup_lambda_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "cleanup_lambda_policy" {
  role       = "${aws_iam_role.cleanup_lambda_role.name}"
  policy_arn = "${aws_iam_policy.cleanup_lambda_policy.arn}"
}

resource "aws_iam_role" "cleanup_lambda_role" {
  name               = "CleanupAccessKeyLambdaRole"
  assume_role_policy = "${data.aws_iam_policy_document.tester_lambda_role_document.json}"
}

data "archive_file" "cleanup_lambda_zip" {
  type        = "zip"
  source_file = "../build/cleanup-lambda"
  output_path = "../build/cleanup-lambda.zip"
}

resource "aws_lambda_function" "cleanup_lambda" {
  filename         = "../build/cleanup-lambda.zip"
  function_name    = "cleanupAccessKey"
  role             = "${aws_iam_role.cleanup_lambda_role.arn}"
  handler          = "cleanup-lambda"
  source_code_hash = "${data.archive_file.cleanup_lambda_zip.output_base64sha256}"
  runtime          = "go1.x"
}

resource "aws_cloudwatch_event_rule" "every_24_hours" {
  name                = "every_24_hours"
  description         = "Fires every 24 hours"
  schedule_expression = "rate(24 hours)"
}

resource "aws_cloudwatch_event_target" "cleanup_rotated_keys_every_24_hours" {
  rule      = "${aws_cloudwatch_event_rule.every_24_hours.name}"
  target_id = "cleanup_lambda"
  arn       = "${aws_lambda_function.cleanup_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_cleanup_rotated_keys" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cleanup_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_24_hours.arn}"
}
