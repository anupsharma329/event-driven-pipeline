variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (optional). If empty, a generated name is used."
  type        = string
  default     = ""
}

variable "raw_bucket_name" {
  description = "S3 bucket name to receive raw events (optional). If empty, a generated name is used."
  type        = string
  default     = ""
}

variable "code_bucket_name" {
  description = "S3 bucket name used for storing lambda code (optional). If empty, a generated name is used)"
  type        = string
  default     = ""
}
