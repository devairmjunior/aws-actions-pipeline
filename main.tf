# Define o provedor AWS
provider "aws" {
  region = "us-east-2"
}

# Criação de um bucket S3
resource "aws_s3_bucket" "my_bucket" {
  bucket = "aws-actions-pipeline"
}
