# main.tf (skeleton)
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
  name_suffix = substr(replace(uuid(), "-", ""), 0, 8)
  lambda_name = var.lambda_function_name != "" ? var.lambda_function_name : "megaminds-processor-${local.name_suffix}"
}

# S3 bucket to receive raw events
resource "aws_s3_bucket" "raw_events" {
  bucket = var.raw_bucket_name != "" ? var.raw_bucket_name : "megaminds-raw-${local.name_suffix}"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "expire-30-days"
    enabled = true
    expiration {
      days = 30
    }
  }
}

# IAM role and policy for Lambda
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

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "megaminds-lambda-policy-${local.name_suffix}"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.raw_events.arn,
          "${aws_s3_bucket.raw_events.arn}/*"
        ]
      }
    ]
  })
}

# Upload local lambda zip to S3 code bucket (optional) - using local file directly for aws_lambda_function

# Create Lambda function using local file
resource "aws_lambda_function" "processor" {
  filename         = "${path.module}/build/processor.zip"
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_fn.processor.handler"
  runtime          = "python3.10"
  timeout          = 30
  publish          = true

  source_code_hash = filebase64sha256("${path.module}/build/processor.zip")
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_events.arn
}

# Create S3 bucket notification to invoke Lambda on object creation
resource "aws_s3_bucket_notification" "raw_to_lambda" {
  bucket = aws_s3_bucket.raw_events.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.processor.function_name}"
  retention_in_days = 14
}
