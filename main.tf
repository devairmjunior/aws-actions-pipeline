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

# Role para a Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role_whatsapp_echo"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Layer para dependências
resource "aws_lambda_layer_version" "dependencies_layer" {
  filename            = "${path.module}/lambda/layer.zip" # Caminho do arquivo layer.zip
  layer_name          = "python-dependencies"
  compatible_runtimes = ["python3.9"]
  description         = "Lambda Layer com dependências Python"
}

# Função Lambda
resource "aws_lambda_function" "whatsapp_echo" {
  function_name    = "cloudEcho"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  handler          = "app.lambda_handler"
  filename         = "${path.module}/lambda/lambda_function.zip" # Caminho do arquivo lambda_function.zip
  source_code_hash = filebase64sha256("${path.module}/lambda/lambda_function.zip")

  # Associando a camada criada
  layers = [aws_lambda_layer_version.dependencies_layer.arn]

  # Variáveis de ambiente
  environment {
    variables = {
      WHATSAPP_TOKEN = var.whatsapp_token
      VERIFY_TOKEN   = var.verify_token
      GEMINI_API_KEY = var.gemini_api_key
    }
  }
}

# Function URL
resource "aws_lambda_function_url" "whatsapp_echo_url" {
  function_name      = aws_lambda_function.whatsapp_echo.arn
  authorization_type = "NONE"
}

# Output da URL da Lambda
output "lambda_function_url" {
  description = "URL pública da Lambda"
  value       = aws_lambda_function_url.whatsapp_echo_url.function_url
}
