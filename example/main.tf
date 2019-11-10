provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

locals {
  build_path = "${path.module}/../build"
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = var.test_bucket
  acl    = "private"
}

resource "aws_s3_bucket_object" "test_object" {
  bucket = aws_s3_bucket.test_bucket.id
  key    = var.test_object
  source = "./test"
  etag   = filemd5("./test")
}

data "aws_iam_policy_document" "app_bot_test_data_policy_document" {
  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.test_bucket.arn}/${var.test_object}",
    ]
  }
}

resource "aws_iam_user_policy" "app_bot_test_data_policy" {
  name   = "GetPermissionTestData"
  user   = var.user_name
  policy = data.aws_iam_policy_document.app_bot_test_data_policy_document.json
}

resource "aws_iam_user_policy" "app_bot1_test_data_policy" {
  name   = "GetPermissionTestData1"
  user   = var.user_name1
  policy = data.aws_iam_policy_document.app_bot_test_data_policy_document.json
}

// Setup the rotate and cleanup lambdas
module "rotator" {
  source = "github.com/pdarg/aws-accesskey-rotator//rotator"

  cloudwatch_retention_days = var.cloudwatch_retention_days
  cleanup_lambda_run_rate   = "1 hour"
}

// Setup the bot users that will have rotatable access keys
module "app_bot" {
  source = "github.com/pdarg/aws-accesskey-rotator//rotatable_user"

  user_name          = var.user_name
  secret_name        = var.secret_name
  rotate_after_days  = var.rotate_after_days
  rotator_lambda_arn = module.rotator.rotator_lambda_arn

  user_tags   = var.default_tags
  secret_tags = var.default_tags

  user_force_destroy = true
}

module "app_bot1" {
  source = "github.com/pdarg/aws-accesskey-rotator//rotatable_user"

  user_name          = var.user_name1
  secret_name        = var.secret_name1
  rotate_after_days  = var.rotate_after_days
  rotator_lambda_arn = module.rotator.rotator_lambda_arn

  user_tags   = var.default_tags
  secret_tags = var.default_tags

  user_force_destroy = true
}
