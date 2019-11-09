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
        "true",
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
  description = "Allows access to get a secret manager secrets, list, update, and delete IAM access keys, and logging from a lambda"
  policy      = data.aws_iam_policy_document.cleanup_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "cleanup_lambda_policy_attachment" {
  role       = aws_iam_role.cleanup_lambda_role.name
  policy_arn = aws_iam_policy.cleanup_lambda_policy.arn
}

resource "aws_iam_role" "cleanup_lambda_role" {
  name               = "CleanupAccessKeyLambdaRole"
  description        = "Allows access to get a secret manager secrets, list, update, and delete IAM access keys, and logging from a lambda"
  assume_role_policy = data.aws_iam_policy_document.cleanup_lambda_role_document.json
}
