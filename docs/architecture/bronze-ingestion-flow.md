# Bronze Ingestion Flow

## Purpose

Describe how Kafka messages are ingested into Delta Bronze tables in the Soccer Intelligence Platform.

## Input

Kafka topic pattern:

- `soccer.raw.ingestion*`

Kafka message value:

- JSON serialized `IngestionEnvelope`

## Output Tables

- `bronze.raw_ingestion_events`
- `bronze.raw_ingestion_quarantine`

## Flow

1. Read Kafka as a streaming source.
2. Preserve Kafka transport metadata.
3. Parse the outer `IngestionEnvelope`.
4. Add ingestion metadata such as `ingested_at_utc`, `event_date`, and `idempotency_key`.
5. Append valid records to `bronze.raw_ingestion_events`.
6. Append malformed or invalid records to `bronze.raw_ingestion_quarantine`.

## Bronze Rules

- Bronze is append-only.
- Bronze preserves raw payloads.
- Bronze does not deeply parse football semantics.
- Bronze and quarantine remain separate.
- Bronze supports replay and downstream reprocessing.

## Replay Model

Bronze must preserve enough information to rebuild downstream layers without depending on the source API.

## Partitioning

- Partition `bronze.raw_ingestion_events` by `event_date`
- Partition `bronze.raw_ingestion_quarantine` by `event_date`

