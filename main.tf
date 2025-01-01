###########################################################
# main.tf
#
# Exemplo mínimo para subir uma Lambda Node.js no AWS,
# com role, policy, e function URL (auth = NONE).
###########################################################

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

#------------------------------------------------------------------
# 1. Criar Role e Política Básica para a Lambda
#------------------------------------------------------------------
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

#------------------------------------------------------------------
# 2. Criar a Função Lambda
#------------------------------------------------------------------
# Observação: Aqui estamos usando o "filebase64" apontando para um
# zip local com o index.js. Ajuste se quiser embutir inline ou
# usar outro método (por ex., s3_key).
# No exemplo, consideramos que você fará um zip do seu "index.js"
# e colocará dentro da pasta "lambda" (lambda/index.js).
# 
# Ex.: 
#    cd lambda
#    zip function.zip index.js
#
# Então no Terraform:
#   filename = "lambda/function.zip"
#
resource "aws_lambda_function" "whatsapp_echo" {
  function_name = "cloudEcho"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "nodejs16.x"
  handler       = "index.handler"

  filename         = "lambda/function.zip"   # Ajuste o caminho do seu zip
  source_code_hash = filebase64sha256("lambda/function.zip")

  # Passar variáveis ao Lambda:
  environment {
    variables = {
      WHATSAPP_TOKEN = var.whatsapp_token
      VERIFY_TOKEN   = var.verify_token
    }
  }
}

#------------------------------------------------------------------
# 3. Criar a Function URL (sem auth)
#------------------------------------------------------------------
resource "aws_lambda_function_url" "whatsapp_echo_url" {
  function_name      = aws_lambda_function.whatsapp_echo.arn
  authorization_type = "NONE"
}

#------------------------------------------------------------------
# 4. Saída com a URL gerada
#------------------------------------------------------------------
output "lambda_function_url" {
  description = "URL pública da Lambda"
  value       = aws_lambda_function_url.whatsapp_echo_url.function_url
}
