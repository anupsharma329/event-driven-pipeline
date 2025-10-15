variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

# S3
variable "existing_s3" {
  description = "Set to true if you want to reuse an existing S3 bucket"
  type        = bool
  default     = false
}

variable "existing_bucket_name" {
  description = "Name of the existing S3 bucket to reuse (when existing_s3 = true)"
  type        = string
  default     = ""
}

variable "new_bucket_name" {
  description = "Name for the new bucket to create (when existing_s3 = false)"
  type        = string
  default     = "event-driven-data-unique-bucket-123456" # change this to a unique name
}

# Lambda
variable "existing_lambda" {
  description = "Set to true if you want to reuse an existing Lambda function"
  type        = bool
  default     = false
}

variable "existing_lambda_name" {
  description = "Name of an existing Lambda to reuse (when existing_lambda = true)"
  type        = string
  default     = ""
}

variable "new_lambda_name" {
  description = "Name for the Lambda to create (when existing_lambda = false)"
  type        = string
  default     = "event_processor_lambda"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment zip (relative to terraform working dir)"
  type        = string
  default     = "../lambda/lambda_package.zip"
}

# Schedule
variable "daily_cron" {
  description = "Cron or rate expression for the daily summary (EventBridge). Default: daily at 00:00 UTC"
  type        = string
  default     = "cron(0 0 * * ? *)"
}
