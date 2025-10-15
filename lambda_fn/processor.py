import json
import logging
import os
import boto3
from datetime import datetime, timezone
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
BUCKET = os.environ.get("BUCKET", "")

def process_records(records):
    """Compute count and numeric sums from a list of dicts."""
    total = 0
    sums = {}
    for r in records:
        total += 1
        if not isinstance(r, dict):
            continue
        for k, v in r.items():
            if isinstance(v, (int, float)):
                sums[k] = sums.get(k, 0) + v
    return {"count": total, "sums": sums, "timestamp": datetime.now(timezone.utc).isoformat()}

def read_s3_json(bucket, key):
    resp = s3.get_object(Bucket=bucket, Key=key)
    body = resp["Body"].read().decode("utf-8")
    return json.loads(body)

def write_s3_json(bucket, key, obj):
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(obj).encode("utf-8"))
    logger.info("Wrote %s to s3://%s/%s", key, bucket, key)

def aggregate_processed(bucket, prefix="processed/"):
    """List processed/* summaries, aggregate them, and write a daily report."""
    paginator = s3.get_paginator("list_objects_v2")
    pages = paginator.paginate(Bucket=bucket, Prefix=prefix)
    aggregate = {"count": 0, "sums": {}, "sources": []}
    for p in pages:
        for obj in p.get("Contents", []):
            key = obj["Key"]
            try:
                data = read_s3_json(bucket, key)
            except Exception as e:
                logger.warning("Skipping %s due to error: %s", key, str(e))
                continue
            # expect summary shape {count, sums}
            c = data.get("count", 0)
            aggregate["count"] += c
            for k, v in data.get("sums", {}).items():
                aggregate["sums"][k] = aggregate["sums"].get(k, 0) + v
            aggregate["sources"].append(key)
    # write report
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    dest_key = f"reports/daily-summary-{date_str}.json"
    aggregate["generated_at"] = datetime.now(timezone.utc).isoformat()
    write_s3_json(bucket, dest_key, aggregate)
    return dest_key, aggregate

def handle_s3_event(record):
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]
    logger.info("Processing s3 event for s3://%s/%s", bucket, key)
    try:
        data = read_s3_json(bucket, key)
    except ClientError as e:
        logger.exception("Failed to read object: %s", e)
        raise
    # unwrap
    if isinstance(data, dict) and "items" in data:
        records = data["items"]
    elif isinstance(data, list):
        records = data
    else:
        records = [data]
    summary = process_records(records)
    dest_key = f"processed/{key}.summary.json"
    write_s3_json(bucket, dest_key, summary)
    return dest_key, summary

def handler(event, context):
    logger.info("Received event: %s", json.dumps(event)[:4000])
    # If invoked by EventBridge scheduled rule, event will have "source": "aws.events"
    try:
        if event.get("source") == "aws.events" or event.get("detail-type") == "Scheduled Event":
            logger.info("Scheduled invocation - aggregating processed summaries")
            dest_key, aggregate = aggregate_processed(BUCKET)
            return {"status": "ok", "report_key": dest_key, "aggregate": aggregate}
        # Else assume S3 event
        records = event.get("Records", [])
        if not records:
            logger.info("No Records found in event; attempting aggregation as fallback")
            dest_key, aggregate = aggregate_processed(BUCKET)
            return {"status": "ok", "report_key": dest_key}
        first = records[0]
        if "s3" in first:
            dest_key, summary = handle_s3_event(first)
            return {"status": "ok", "summary_key": dest_key}
        else:
            logger.warning("Unrecognized event shape; returning. Event: %s", event)
            return {"status": "ignored", "reason": "unrecognized event shape"}
    except Exception as e:
        logger.exception("Handler error: %s", e)
        raise
