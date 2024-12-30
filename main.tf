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

resource "aws_iam_policy" "glue_s3_policy" {
  name   = "GlueS3AccessPolicy"
  policy = file("${path.module}/s3_policy.json")
}

resource "aws_iam_role_policy_attachment" "glue_s3_policy_attachment" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
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

# Substituir aws_s3_bucket_object por aws_s3_object
resource "aws_s3_object" "script_object" {
  bucket = aws_s3_bucket.script_bucket.id
  key    = "main.py"
  source = "${path.module}/app/main.py"
  etag   = filemd5("${path.module}/app/main.py") # Adiciona checksum para garantir integridade
}
