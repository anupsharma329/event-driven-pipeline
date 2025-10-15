# Event-Driven Data Processing Pipeline on AWS

## Overview
This project implements an **event-driven data processing pipeline** on AWS that captures incoming JSON data, processes it via AWS Lambda, stores the results in S3, and generates automated summary reports. The infrastructure is fully automated using **Terraform**, and CI/CD is implemented via **GitHub Actions** to handle build, deployment, and Lambda updates.

The pipeline demonstrates a real-world, scalable, and automated architecture suitable for analytics, monitoring, and reporting use cases.

---

## Architecture

### High-Level Flow
1. **Data Ingestion**: JSON files are uploaded to an S3 bucket (`incoming/` prefix).  
2. **Event Trigger**: S3 triggers an AWS Lambda function upon file upload.  
3. **Data Processing**: Lambda reads the JSON file, computes a summary (count and sums of numeric fields), and writes the results to a `processed/` S3 bucket.  
4. **Monitoring & Logging**: All Lambda executions are logged in **CloudWatch Logs**.  
5. **Automation**: Terraform provisions all resources, and GitHub Actions CI/CD pipeline automates Lambda packaging, deployment, and infrastructure management.  




---

## Features
- Event-driven: Lambda automatically processes files when uploaded to S3.  
- Automated CI/CD: GitHub Actions pipeline handles testing, packaging, Terraform deployment, and Lambda updates.  
- Scalable: Easily handles multiple incoming files concurrently.  
- Fault-tolerant: Logs are captured in CloudWatch for error monitoring.  
- IaC: Infrastructure fully managed via Terraform for reproducibility.  

---

## Setup & Deployment

### Prerequisites
- AWS CLI configured with appropriate credentials  
- Terraform installed  
- GitHub repository with secrets:  
  - `AWS_ACCESS_KEY_ID`  
  - `AWS_SECRET_ACCESS_KEY`  
  - `AWS_REGION`  
  - `AWS_LAMBDA_ROLE_ARN`  

### Terraform Deployment
```bash
terraform init
terraform apply -auto-approve

### CI/CD Deployemnt

Push code to the main branch of GitHub

GitHub Actions workflow:

Runs tests

Packages Lambda

Applies Terraform

Deploys Lambda (updates existing or creates new function)


### Drive link 


https://drive.google.com/drive/folders/1wTvjF1Pfd9_Je0q-NdKJYlqTRau-7szH?usp=sharing