# Bronze Table Design

## Purpose

The Bronze layer stores raw ingestion events with enough metadata to support replay, traceability, debugging, and later transformation into Silver.

Bronze is not an analytics layer and is not intended to model football domain semantics deeply.

## Primary Table

- `bronze.raw_ingestion_events`

## Partitioning Strategy

- Partition by `event_date`

## Core Design Principles

- Preserve raw source payload
- Preserve full raw transport message
- Extract enough metadata for filtering and replay
- Keep valid Bronze and quarantined records separate
- Prefer append-only storage
- Carry idempotency metadata for downstream duplicate analysis

## Columns

### Identity and contract
- `schema_version` STRING
- `source` STRING
- `entity_type` STRING
- `request_key` STRING
- `correlation_id` STRING
- `source_entity_id` STRING

### Domain context
- `league_id` INT
- `league_name` STRING
- `season` INT
- `endpoint` STRING

### Time context
- `fetched_at_utc` TIMESTAMP
- `kafka_timestamp_utc` TIMESTAMP
- `ingested_at_utc` TIMESTAMP
- `event_date` DATE

### Broker metadata
- `kafka_topic` STRING
- `kafka_partition` INT
- `kafka_offset` BIGINT

### Raw content
- `payload_json` STRING
- `raw_message_json` STRING

### Operational metadata
- `idempotency_key` STRING
- `ingestion_status` STRING
- `quarantined` BOOLEAN

## Non-Goals

Bronze does not:
- parse football entities deeply
- compute analytics
- flatten event-specific semantics into many columns
- replace Silver normalization

## Replay Strategy

Bronze must preserve enough information to allow downstream reprocessing without depending on the source API still being available or unchanged.

