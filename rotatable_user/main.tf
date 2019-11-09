resource "aws_iam_user" "rotatable_user" {
  name = var.user_name

  tags = "${merge(map("Rotatable", "true"), var.user_tags)}"
}

resource "aws_secretsmanager_secret" "rotatable_secret" {
  name                = var.secret_name
  rotation_lambda_arn = var.rotator_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotate_after_days
  }

  tags = "${merge(map("Rotatable", "true"), var.secret_tags)}"
}

resource "aws_secretsmanager_secret_version" "rotatable_secret" {
  secret_id     = aws_secretsmanager_secret.rotatable_secret.id
  secret_string = "{\"UserName\":\"${aws_iam_user.rotatable_user.name}\"}"
}
