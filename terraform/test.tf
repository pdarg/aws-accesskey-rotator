resource "aws_cloudwatch_log_group" "test_cloudwatch_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.tester_lambda.function_name}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "tester_lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.test_cloudwatch_log_group.name}:*",
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
}

data "aws_iam_policy_document" "tester_lambda_role_document" {
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

resource "aws_iam_policy" "tester_lambda_policy" {
  name        = "TestAccessKeyLambdaPolicy"
  path        = "/"
  description = "Allows access to get a secrets manager secret and write logs"
  policy      = "${data.aws_iam_policy_document.tester_lambda_policy_document.json}"
}

resource "aws_iam_role_policy_attachment" "tester_lambda" {
  role       = "${aws_iam_role.tester_lambda_role.name}"
  policy_arn = "${aws_iam_policy.tester_lambda_policy.arn}"
}

resource "aws_iam_role" "tester_lambda_role" {
  name               = "TestAccessKeyLambdaRole"
  assume_role_policy = "${data.aws_iam_policy_document.tester_lambda_role_document.json}"
}

data "archive_file" "tester_lambda_zip" {
  type        = "zip"
  source_file = "../build/tester-lambda"
  output_path = "../build/tester-lambda.zip"
}

resource "aws_lambda_function" "tester_lambda" {
  filename         = "../build/tester-lambda.zip"
  function_name    = "testAccessKey"
  role             = "${aws_iam_role.tester_lambda_role.arn}"
  handler          = "tester-lambda"
  source_code_hash = "${data.archive_file.tester_lambda_zip.output_base64sha256}"
  runtime          = "go1.x"

  environment {
    variables = {
      TEST_BUCKET = "app-bot-test-bucket"
      TEST_OBJECT = "test"
    }
  }
}

resource "aws_cloudwatch_event_rule" "every_1_hour" {
  name                = "every_1_hour"
  description         = "Fires every 1 hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "test_rotated_keys_every_1_hour" {
  rule      = "${aws_cloudwatch_event_rule.every_1_hour.name}"
  target_id = "tester_lambda"
  arn       = "${aws_lambda_function.tester_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_test_rotated_keys" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.tester_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_1_hour.arn}"
}
