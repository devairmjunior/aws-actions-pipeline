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
# Lambda Layer para dependências Python (drive-api)
################################################################################
resource "aws_lambda_layer_version" "drive_api_layer" {
  # Ajuste o caminho do ZIP conforme onde você salvou o arquivo
  filename             = "${path.module}/lambda/drive-api.zip"
  layer_name           = "drive-api"
  description          = "Camada com google-api-python-client e dependências"
  compatible_runtimes  = ["python3.9"]
  compatible_architectures = ["x86_64"]    # Se quiser suportar arm64 também, inclua aqui
}

################################################################################
# Função Lambda principal
################################################################################
resource "aws_lambda_function" "whatsapp_echo" {
  function_name    = "cloudEcho"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/lambda/lambda_function.zip" 
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda_function.zip")

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
