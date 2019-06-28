provider "aws" {
  region  = "us-west-2"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_object" "test_object" {
  bucket = "${aws_s3_bucket.key_test_bucket.id}"
  key    = "test"
  source = "./test"
  etag = "${filemd5("./test")}"
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

resource "aws_secretsmanager_secret" "rotatable_secret" {
  name                = "dev/rotatable-secret"
  rotation_lambda_arn = "${aws_lambda_function.rotate_lambda.arn}"

  rotation_rules {
    automatically_after_days = 7
  }
}
