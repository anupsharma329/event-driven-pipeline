terraform {
  required_version = ">= 1.0.0"
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

### ----------------------------
### Conditional S3: reuse or create
### ----------------------------
# Create bucket if existing_s3 is false
resource "aws_s3_bucket" "data_bucket" {
  count = var.existing_s3 ? 0 : 1
  bucket = var.new_bucket_name
  acl    = "private"

  tags = {
    Name = "event-driven-data-bucket"
    Env  = var.environment
  }
}

# Reference existing bucket if requested
data "aws_s3_bucket" "existing_bucket" {
  count  = var.existing_s3 ? 1 : 0
  bucket = var.existing_bucket_name
}

locals {
  bucket_name = var.existing_s3 ? data.aws_s3_bucket.existing_bucket[0].bucket : aws_s3_bucket.data_bucket[0].bucket
}

### ----------------------------
### IAM Role for Lambda
### ----------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "${var.environment}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags = {
    Env = var.environment
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.environment}-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = data.aws_iam_policy_document.lambda_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "S3Access"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
      "arn:aws:s3:::${local.bucket_name}",
      "arn:aws:s3:::${local.bucket_name}/*"
    ]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

### ----------------------------
### Lambda: reuse or create
### ----------------------------
# If user says reuse existing lambda, get its ARN, otherwise create a new one.
data "aws_lambda_function" "existing_lambda" {
  count = var.existing_lambda ? 1 : 0
  function_name = var.existing_lambda_name
}

resource "aws_lambda_function" "processor" {
  count = var.existing_lambda ? 0 : 1

  filename         = var.lambda_zip_path
  function_name    = var.new_lambda_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_handler.handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  timeout          = 30

  environment {
    variables = {
      BUCKET = local.bucket_name
    }
  }

  tags = {
    Env = var.environment
  }
}

# Expose arn every time via local
locals {
  lambda_arn = var.existing_lambda ? data.aws_lambda_function.existing_lambda[0].arn : aws_lambda_function.processor[0].arn
  lambda_name = var.existing_lambda ? data.aws_lambda_function.existing_lambda[0].function_name : aws_lambda_function.processor[0].function_name
}

### ----------------------------
### S3 Notification (object created) -> Lambda
### Only create notification if we created the lambda and/or bucket (safe)
### ----------------------------
resource "aws_s3_bucket_notification" "bucket_to_lambda" {
  count = var.existing_s3 || var.existing_lambda ? 0 : 1

  bucket = aws_s3_bucket.data_bucket[0].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# If bucket existed but we created lambda, attach notification via aws_s3_bucket_notification with existing bucket id
resource "aws_s3_bucket_notification" "attach_to_existing_bucket" {
  count = var.existing_s3 && !var.existing_lambda ? 1 : 0
  bucket = data.aws_s3_bucket.existing_bucket[0].bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Permission for S3 to invoke Lambda (only when we created the lambda)
resource "aws_lambda_permission" "allow_s3" {
  count = var.existing_lambda ? 0 : 1
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor[0].function_name
  principal     = "s3.amazonaws.com"
  # source_arn would be useful but for simplicity allow from account
  # source_arn = "arn:aws:s3:::${local.bucket_name}"
}

### ----------------------------
### EventBridge schedule (daily summary run)
### The schedule will invoke the Lambda to aggregate processed summaries daily at the specified cron.
### If using existing lambda, we'll create permission + rule to invoke it.
### ----------------------------
resource "aws_cloudwatch_event_rule" "daily_summary" {
  name                = "${var.environment}-daily-summary"
  description         = "Daily trigger for summary aggregation"
  schedule_expression = var.daily_cron
}

resource "aws_cloudwatch_event_target" "target_lambda" {
  rule = aws_cloudwatch_event_rule.daily_summary.name
  arn  = local.lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = 1
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_summary.arn
}

### ----------------------------
### Optional: Create prefix object to ensure bucket exists for notification to work (only if created)
### ----------------------------
resource "aws_s3_bucket_object" "placeholder" {
  count  = var.existing_s3 ? 0 : 1
  bucket = aws_s3_bucket.data_bucket[0].id
  key    = "._init_bucket"
  content = "init"
  acl    = "private"
}

