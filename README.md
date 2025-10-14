# Megaminds Event-driven Pipeline (sample)

This repository contains a sample event-driven data ingestion and processing pipeline designed for the assignment. It includes:

- Terraform infra skeleton (`main.tf`) for AWS resources (S3, EventBridge, Lambda, IAM)
- Lambda function (in `lambda_fn/processor.py`) to process S3 JSON objects and write summaries
- Packaging script to create `build/processor.zip`
- GitHub Actions workflow for CI/CD (build, test, terraform plan/apply)
- Placeholder docs for Research and Architecture

See `/docs` for the Research Report and Architecture files you'll need to produce.
