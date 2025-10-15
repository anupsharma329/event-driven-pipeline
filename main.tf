terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_suffix = "prod"  # Changed to avoid conflicts
  lambda_name = var.lambda_function_name != "" ? var.lambda_function_name : "megaminds-processor-${local.name_suffix}"
}

# S3 bucket to receive raw events
resource "aws_s3_bucket" "raw_events" {
  bucket = var.raw_bucket_name != "" ? var.raw_bucket_name : "megaminds-raw-${local.name_suffix}"
}

# Versioning configuration
resource "aws_s3_bucket_versioning" "raw_events" {
  bucket = aws_s3_bucket.raw_events.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_events" {
  bucket = aws_s3_bucket.raw_events.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "raw_events" {
  bucket = aws_s3_bucket.raw_events.id

  rule {
    id     = "expire-30-days"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# IAM role and policy for Lambda (rest of your code remains the same)
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "megaminds-lambda-role-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# ADD THESE IAM POLICIES FOR LAMBDA
data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.raw_events.arn,
      "${aws_s3_bucket.raw_events.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "megaminds-lambda-policy-${local.name_suffix}"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# ADD THE MISSING LAMBDA FUNCTION RESOURCE
resource "aws_lambda_function" "processor" {
  filename      = var.lambda_zip_path != "" ? var.lambda_zip_path : "lambda-function.zip"
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = var.lambda_handler != "" ? var.lambda_handler : "index.handler"
  runtime       = var.lambda_runtime != "" ? var.lambda_runtime : "python3.9"

  source_code_hash = filebase64sha256(var.lambda_zip_path != "" ? var.lambda_zip_path : "lambda-function.zip")
  
  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.raw_events.bucket
      AWS_REGION     = var.aws_region
    }
  }

  tags = {
    Environment = "production"
    Project     = "megaminds"
  }
}

# OPTIONAL: Add Lambda permissions for other services (if needed)
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_events.arn
}