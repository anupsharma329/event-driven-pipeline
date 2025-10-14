import json
import logging
import os
from datetime import datetime
import boto3

# -----------------------------
# Setup Logger
# -----------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# -----------------------------
# AWS S3 Client
# -----------------------------
S3_BUCKET = os.environ.get("RAW_BUCKET")  # fallback not needed, using Terraform bucket
S3_CLIENT = boto3.client("s3")

# -----------------------------
# Pure processing function
# -----------------------------
def process_records(records):
    """
    Computes:
      - count of records
      - sums of numeric fields per key
    Input: list of dicts
    Output: summary dict
    """
    total = 0
    sums = {}
    for r in records:
        total += 1
        for k, v in r.items():
            if isinstance(v, (int, float)):
                sums[k] = sums.get(k, 0) + v

    return {"count": total, "sums": sums, "timestamp": datetime.utcnow().isoformat()}

# -----------------------------
# Lambda handler
# -----------------------------
def handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    # Extract S3 object info
    try:
        rec = event["Records"][0]
        bucket = rec["s3"]["bucket"]["name"]
        key = rec["s3"]["object"]["key"]
        logger.info("Processing S3 object: s3://%s/%s", bucket, key)
    except Exception:
        logger.exception("Failed to parse S3 event")
        raise

    # Download object from S3
    try:
        obj = S3_CLIENT.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8")
        data = json.loads(body)

        # -----------------------------
        # Handle JSON structure
        # -----------------------------
        # 1. If top-level dict with 'items', use the items array
        # 2. If top-level list, use directly
        # 3. Otherwise wrap single dict into a list
        if isinstance(data, dict) and "items" in data and isinstance(data["items"], list):
            records = data["items"]
        elif isinstance(data, list):
            records = data
        else:
            records = [data]

        logger.info("Number of records to process: %d", len(records))

    except Exception:
        logger.exception("Failed to read or parse S3 object %s/%s", bucket, key)
        raise

    # Process records
    summary = process_records(records)

    # Upload summary back to S3
    dest_key = f"processed/{key}.summary.json"
    try:
        S3_CLIENT.put_object(
            Bucket=bucket,
            Key=dest_key,
            Body=json.dumps(summary, indent=2).encode("utf-8"),
        )
        logger.info("Wrote summary to s3://%s/%s", bucket, dest_key)
    except Exception:
        logger.exception("Failed to write summary to s3://%s/%s", bucket, dest_key)
        raise

    return {"status": "ok", "summary_key": dest_key}

# -----------------------------
# Local testing
# -----------------------------
if __name__ == "__main__":
    sample = [
        {"id": 1, "value": 10},
        {"id": 2, "value": 25},
        {"id": 3, "value": 15}
    ]
    print(process_records(sample))
