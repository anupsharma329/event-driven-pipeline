variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = ""
}

variable "raw_bucket_name" {
  description = "Name of the raw events S3 bucket"
  type        = string
  default     = ""
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
  default     = ""
}

variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = ""
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = ""
}