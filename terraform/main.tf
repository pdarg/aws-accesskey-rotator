provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_object" "test_object" {
  bucket = "${aws_s3_bucket.key_test_bucket.id}"
  key    = "test"
  source = "./test"
  etag   = "${filemd5("./test")}"
}

resource "aws_s3_bucket" "key_test_bucket" {
  bucket = "app-bot-test-bucket"
  acl    = "private"
}

data "aws_iam_policy_document" "app_bot_test_data_policy_document" {
  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.key_test_bucket.arn}/test",
    ]
  }
}

#
# App Bot
#
resource "aws_iam_user" "app_bot" {
  name = "app-bot"

  tags = {
    Rotatable = true
  }
}

resource "aws_iam_user_policy" "app_bot_test_data" {
  name   = "GetPermissionTestData"
  user   = "${aws_iam_user.app_bot.name}"
  policy = "${data.aws_iam_policy_document.app_bot_test_data_policy_document.json}"
}

resource "aws_secretsmanager_secret" "rotatable_secret" {
  name                = "dev/rotatable-secret"
  rotation_lambda_arn = "${aws_lambda_function.rotate_lambda.arn}"

  rotation_rules {
    automatically_after_days = 7
  }

  tags = {
    Rotatable = true
  }
}

resource "aws_secretsmanager_secret_version" "rotatable_secret" {
  secret_id     = "${aws_secretsmanager_secret.rotatable_secret.id}"
  secret_string = "{\"UserName\":\"${aws_iam_user.app_bot.name}\"}"
}


#
# App Bot 1
#
resource "aws_iam_user" "app_bot1" {
  name = "app-bot1"

  tags = {
    Rotatable = true
  }
}

resource "aws_iam_user_policy" "app_bot1_test_data" {
  name   = "GetPermissionTestData1"
  user   = "${aws_iam_user.app_bot1.name}"
  policy = "${data.aws_iam_policy_document.app_bot_test_data_policy_document.json}"
}

resource "aws_secretsmanager_secret" "rotatable_secret1" {
  name                = "dev/rotatable-secret1"
  rotation_lambda_arn = "${aws_lambda_function.rotate_lambda.arn}"

  rotation_rules {
    automatically_after_days = 7
  }

  tags = {
    Rotatable = true
  }
}

resource "aws_secretsmanager_secret_version" "rotatable_secret1" {
  secret_id     = "${aws_secretsmanager_secret.rotatable_secret1.id}"
  secret_string = "{\"UserName\":\"${aws_iam_user.app_bot1.name}\"}"
}
