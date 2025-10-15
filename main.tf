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

# ... rest of your IAM and Lambda configuration