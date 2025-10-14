output "raw_bucket_name" {
  description = "Raw events S3 bucket name"
  value       = aws_s3_bucket.raw_events.bucket
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_role_arn" {
  description = "IAM role ARN used by Lambda"
  value       = aws_iam_role.lambda_role.arn
}
