data "aws_caller_identity" "current" {}

locals {
  build_path  = "${path.module}/../build"
  source_path = "${path.module}/lambda"
}
