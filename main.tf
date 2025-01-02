terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

################################################################################
# S3 Bucket para o código da Lambda
################################################################################
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket        = "lambda-code-whatsapp-echo"
  force_destroy = true # Cuidado ao usar em produção; remove todos os objetos ao destruir o bucket
}

resource "aws_s3_object" "lambda_function_zip" {
  bucket       = aws_s3_bucket.lambda_code_bucket.id
  key          = "lambda_function.zip"
  source       = "${path.module}/lambda/lambda_function.zip"
  content_type = "application/zip"
}

################################################################################
# IAM Role para a Lambda
################################################################################
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role_whatsapp_echo"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# Lambda Layer para dependências Python (libs)
################################################################################
resource "aws_lambda_layer_version" "drive_api_layer" {
  filename                = "${path.module}/lambda/libs.zip"
  layer_name              = "libs"
  description             = "Camada com google-api-python-client e dependências"
  compatible_runtimes     = ["python3.12"]
  compatible_architectures = ["x86_64"]
}

################################################################################
# Função Lambda principal
################################################################################
resource "aws_lambda_function" "whatsapp_echo" {
  function_name    = "cloudEcho"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12" # Alterado para Python 3.12
  handler          = "app.lambda_handler"

  # Usando o bucket S3 como fonte do código
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.id
  s3_key           = aws_s3_object.lambda_function_zip.key

  # Referência à camada criada acima
  layers = [
    aws_lambda_layer_version.drive_api_layer.arn
  ]

  # Configurações de timeout e memória
  timeout     = 15
  memory_size = 256

  # Variáveis de ambiente
  environment {
    variables = {
      WHATSAPP_TOKEN = var.whatsapp_token
      VERIFY_TOKEN   = var.verify_token
      GEMINI_API_KEY = var.gemini_api_key
    }
  }
}

################################################################################
# Lambda Function URL (para expor uma URL pública, se desejado)
################################################################################
resource "aws_lambda_function_url" "whatsapp_echo_url" {
  function_name      = aws_lambda_function.whatsapp_echo.arn
  authorization_type = "NONE"
}

################################################################################
# Output da Function URL
################################################################################
output "lambda_function_url" {
  description = "Public URL for the Lambda Function"
  value       = aws_lambda_function_url.whatsapp_echo_url.function_url
}
