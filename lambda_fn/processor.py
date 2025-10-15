import json
import boto3
from datetime import datetime, timedelta
import os

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# DynamoDB table for daily summaries
SUMMARY_TABLE = os.environ.get('SUMMARY_TABLE', 'daily-summaries')

def handler(event, context):
    """
    Process incoming JSON files from S3 and generate daily summaries
    """
    print(f"Processing event: {json.dumps(event)}")
    
    try:
        # Process each S3 event record
        for record in event['Records']:
            if 's3' in record:
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                print(f"Processing file: s3://{bucket}/{key}")
                
                # Get the JSON file from S3
                response = s3_client.get_object(Bucket=bucket, Key=key)
                json_data = json.loads(response['Body'].read().decode('utf-8'))
                
                # Process the JSON data
                process_json_data(json_data, key)
                
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Processing completed successfully'})
        }
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_json_data(data, source_key):
    """
    Process JSON data and update daily summaries
    """
    try:
        # Extract date from filename or use current date
        processing_date = datetime.now().strftime('%Y-%m-%d')
        
        # Sample processing - count records, calculate totals, etc.
        summary = {
            'date': processing_date,
            'total_records': len(data) if isinstance(data, list) else 1,
            'data_type': infer_data_type(data),
            'source_file': source_key,
            'processed_at': datetime.now().isoformat(),
            'total_amount': calculate_total_amount(data),
            'record_count': count_records(data)
        }
        
        # Store summary in DynamoDB
        store_daily_summary(summary)
        
        print(f"Processed summary: {summary}")
        
    except Exception as e:
        print(f"Error processing JSON data: {str(e)}")

def infer_data_type(data):
    """Infer data type from JSON structure"""
    if isinstance(data, list):
        if data and 'transaction' in data[0]:
            return 'transactions'
        elif data and 'user' in data[0]:
            return 'user_activity'
    return 'generic'

def calculate_total_amount(data):
    """Calculate total amount from transaction data"""
    total = 0
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict) and 'amount' in item:
                total += float(item.get('amount', 0))
    return total

def count_records(data):
    """Count records in the data"""
    if isinstance(data, list):
        return len(data)
    return 1

def store_daily_summary(summary):
    """Store daily summary in DynamoDB"""
    try:
        table = dynamodb.Table(SUMMARY_TABLE)
        table.put_item(Item=summary)
        print(f"Stored summary for date: {summary['date']}")
    except Exception as e:
        print(f"Error storing summary: {str(e)}")