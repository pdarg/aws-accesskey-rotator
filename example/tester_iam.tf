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
        "true",
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
  policy      = data.aws_iam_policy_document.tester_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "tester_lambda" {
  role       = aws_iam_role.tester_lambda_role.name
  policy_arn = aws_iam_policy.tester_lambda_policy.arn
}

resource "aws_iam_role" "tester_lambda_role" {
  name               = "TestAccessKeyLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.tester_lambda_role_document.json
}
