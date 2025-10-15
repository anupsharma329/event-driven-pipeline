output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.processor.arn
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda_role.arn
}

output "raw_bucket_name" {
  description = "The name of the raw events S3 bucket"
  value       = aws_s3_bucket.raw_events.bucket
}