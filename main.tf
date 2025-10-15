terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_suffix = "prod"
  lambda_name = var.lambda_function_name != "" ? var.lambda_function_name : "megaminds-processor-${local.name_suffix}"
}

# S3 bucket for raw JSON events
resource "aws_s3_bucket" "raw_events" {
  bucket = var.raw_bucket_name != "" ? var.raw_bucket_name : "megaminds-raw-${local.name_suffix}"
  
  tags = {
    Environment = "production"
    Project     = "event-pipeline"
  }
}

resource "aws_s3_bucket_versioning" "raw_events" {
  bucket = aws_s3_bucket.raw_events.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_events" {
  bucket = aws_s3_bucket.raw_events.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for processed data
resource "aws_s3_bucket" "processed_data" {
  bucket = "megaminds-processed-${local.name_suffix}"
  
  tags = {
    Environment = "production"
    Project     = "event-pipeline"
  }
}

# DynamoDB for daily summaries
resource "aws_dynamodb_table" "daily_summaries" {
  name           = "daily-summaries-${local.name_suffix}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "date"
  range_key      = "processed_at"

  attribute {
    name = "date"
    type = "S"
  }

  attribute {
    name = "processed_at"
    type = "S"
  }

  tags = {
    Environment = "production"
    Project     = "event-pipeline"
  }
}

# IAM role for Lambda
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

# Enhanced IAM policies for Lambda
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
      "${aws_s3_bucket.raw_events.arn}/*",
      aws_s3_bucket.processed_data.arn,
      "${aws_s3_bucket.processed_data.arn}/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [aws_dynamodb_table.daily_summaries.arn]
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "megaminds-lambda-policy-${local.name_suffix}"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# Lambda function
resource "aws_lambda_function" "processor" {
  filename      = "lambda-function.zip"
  function_name = local.lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 60

  environment {
    variables = {
      SUMMARY_TABLE    = aws_dynamodb_table.daily_summaries.name
      PROCESSED_BUCKET = aws_s3_bucket.processed_data.bucket
      AWS_REGION       = var.aws_region
    }
  }

  tags = {
    Environment = "production"
    Project     = "event-pipeline"
  }
}

# S3 trigger for Lambda
resource "aws_lambda_permission" "s3_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_events.arn
}

resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.raw_events.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.s3_trigger]
}

# CloudWatch Event for daily report generation
resource "aws_cloudwatch_event_rule" "daily_report" {
  name                = "daily-report-generation"
  description         = "Trigger daily report generation"
  schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
}

resource "aws_cloudwatch_event_target" "daily_report_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_report.name
  target_id = "GenerateDailyReport"
  arn       = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "cloudwatch_report" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report.arn
}