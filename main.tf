provider "aws" {
  region = "us-east-2"
}

resource "aws_iam_role" "glue_role" {
  name               = "GlueRole"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role_policy.json
}

data "aws_iam_policy_document" "glue_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_glue_job" "glue_job" {
  name     = "my-glue-job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    script_location = "s3://${aws_s3_bucket.script_bucket.id}/main.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language" = "python"
    "--TempDir"      = "s3://${aws_s3_bucket.script_bucket.id}/temp/"
  }

  max_retries = 1
}

resource "aws_s3_bucket" "script_bucket" {
  bucket = "glue-scripts-bucket-devair"
}

resource "aws_s3_bucket_object" "script_object" {
  bucket = aws_s3_bucket.script_bucket.id
  key    = "main.py"
  source = "${path.module}/app/main.py"
}
  