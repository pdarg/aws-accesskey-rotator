resource "aws_iam_user" "rotatable_user" {
  name = var.user_name

  force_destroy        = var.user_force_destroy
  path                 = var.user_path
  permissions_boundary = var.user_permissions_boundary

  tags = "${merge(map("Rotatable", "true"), var.user_tags)}"
}

resource "aws_secretsmanager_secret" "rotatable_secret" {
  name                = var.secret_name
  rotation_lambda_arn = var.rotator_lambda_arn

  description             = var.secret_description
  kms_key_id              = var.secret_kms_key_id
  name_prefix             = var.secret_name_prefix
  policy                  = var.secret_policy
  recovery_window_in_days = var.secret_recovery_window_in_days

  rotation_rules {
    automatically_after_days = var.rotate_after_days
  }

  tags = "${merge(map("Rotatable", "true"), var.secret_tags)}"
}

resource "aws_secretsmanager_secret_version" "rotatable_secret" {
  secret_id     = aws_secretsmanager_secret.rotatable_secret.id
  secret_string = "{\"UserName\":\"${aws_iam_user.rotatable_user.name}\"}"
}
