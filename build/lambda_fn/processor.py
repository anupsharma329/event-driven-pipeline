import json
import logging
import os
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

S3_BUCKET = os.environ.get("RAW_BUCKET") or "megaminds-raw-events"
S3_CLIENT = boto3.client("s3")


def process_records(records):
    """Pure function to process a list of event records (dicts).

    For sample data this computes simple aggregates: count and numeric field sums.
    Returns a summary dict.
    """
    total = 0
    sums = {}
    for r in records:
        total += 1
        for k, v in r.items():
            if isinstance(v, (int, float)):
                sums[k] = sums.get(k, 0) + v

    return {"count": total, "sums": sums, "timestamp": datetime.utcnow().isoformat()}


def handler(event, context):
    """AWS Lambda handler triggered by S3 put events containing JSON payloads.

    The function will:
    - Read the uploaded S3 object (expects JSON array or single json object)
    - Compute a small per-file summary via process_records
    - Write the summary back to S3 under the `processed/` prefix next to original key
    """
    logger.info("Received event: %s", json.dumps(event))

    # Extract S3 object info
    try:
        rec = event["Records"][0]
        bucket = rec["s3"]["bucket"]["name"]
        key = rec["s3"]["object"]["key"]
    except Exception as e:
        logger.exception("Failed to parse event")
        raise

    # Download object
    try:
        obj = S3_CLIENT.get_object(Bucket=bucket, Key=key)
        body = obj["Body"].read().decode("utf-8")
        data = json.loads(body)
        # normalize to list
        records = data if isinstance(data, list) else [data]
    except Exception:
        logger.exception("Failed to read or parse S3 object %s/%s", bucket, key)
        raise

    summary = process_records(records)

    # Build destination key
    dest_key = f"processed/{key}.summary.json"
    try:
        S3_CLIENT.put_object(Bucket=bucket, Key=dest_key, Body=json.dumps(summary).encode("utf-8"))
        logger.info("Wrote summary to s3://%s/%s", bucket, dest_key)
    except Exception:
        logger.exception("Failed to write summary to s3://%s/%s", bucket, dest_key)
        raise

    return {"status": "ok", "summary_key": dest_key}


if __name__ == "__main__":
    # local smoke run for quick dev
    sample = [{"value": 10, "x": 1}, {"value": 5, "x": 3}]
    print(process_records(sample))
