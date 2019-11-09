data "aws_iam_policy_document" "rotate_lambda_policy_document" {
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
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
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
        "true",
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
        "true",
      ]
    }
  }
}

data "aws_iam_policy_document" "rotate_lambda_role_document" {
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

resource "aws_iam_policy" "rotate_lambda_policy" {
  name        = "RotateAccessKeyLambdaPolicy"
  path        = "/"
  description = "Allows access to get and update secrets manager secrets, create new IAM access keys, and logging from a lambda"
  policy      = data.aws_iam_policy_document.rotate_lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "rotate_lambda_policy_attachment" {
  role       = aws_iam_role.rotate_lambda_role.name
  policy_arn = aws_iam_policy.rotate_lambda_policy.arn
}

resource "aws_iam_role" "rotate_lambda_role" {
  name               = "RotateAccessKeyLambdaRole"
  description        = "Allows access to get and update secrets manager secrets, create new IAM access keys, and logging from a lambda"
  assume_role_policy = data.aws_iam_policy_document.rotate_lambda_role_document.json
}
