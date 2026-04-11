# Bronze Stream Implementation Notes

## Runtime Shape

Bronze ingestion runs as a dedicated Kafka -> Delta streaming job.

It is responsible only for:
- reading Kafka
- parsing the outer `IngestionEnvelope`
- preserving transport metadata
- writing valid records to `bronze.raw_ingestion_events`
- writing invalid records to `bronze.raw_ingestion_quarantine`

It is not responsible for:
- football-semantic normalization
- deduplication of business entities
- analytics or serving logic

## Checkpoints

Use distinct checkpoints for:
- valid Bronze writes
- quarantine writes

This prevents stream progress from being ambiguous and aligns with Databricks streaming checkpoint behavior.

## Offsets

Use Kafka offsets as transport metadata and for diagnostics, but do not rely on them as the business identity key.

## Duplicate Strategy

Carry `idempotency_key` in Bronze.
Prevent obvious duplicates at ingestion edges where practical.
Expect Silver to remain capable of deduplication during replay or recovery.

## JSON Parsing Strategy

Parse only the outer envelope in Bronze.
Keep `payload_json` as raw text.
Do not deeply parse football payloads in Bronze.

## Table Strategy

- `bronze.raw_ingestion_events`
- `bronze.raw_ingestion_quarantine`

Both should be append-only and partitioned by `event_date`.

