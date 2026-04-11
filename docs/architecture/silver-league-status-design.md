# Silver League Status Design

## Purpose

The Silver layer transforms accepted Bronze ingestion events into validated, typed, deduplicated records suitable for downstream use.

This first Silver design focuses on `league-status` events.

## Source Table

- `bronze.raw_ingestion_events`

## Target Table

- `silver.league_status_events`

## Selection Rule

Read only rows where:
- `entity_type = 'league-status'`
- `quarantined = false`
- `ingestion_status = 'accepted'`

## Silver Responsibilities

- validate required fields again at the Silver boundary
- parse `payload_json` into typed columns where useful
- deduplicate by `idempotency_key`
- preserve raw payload and raw message for traceability

## Core Columns

### Identity and lineage
- `idempotency_key`
- `schema_version`
- `source`
- `entity_type`
- `request_key`
- `correlation_id`
- `source_entity_id`

### Domain context
- `league_id`
- `league_name`
- `season`
- `endpoint`

### Parsed payload fields
- `api_status`
- `api_response_length`
- `api_warning`

### Time and transport
- `fetched_at_utc`
- `kafka_timestamp_utc`
- `ingested_at_utc`
- `event_date`

### Raw preservation
- `payload_json`
- `raw_message_json`

## Deduplication Rule

Use `idempotency_key` as the deduplication key.

When multiple rows share the same `idempotency_key`, keep the latest row by `ingested_at_utc`.

## Non-Goals

This Silver table does not:
- model fixtures
- model standings
- compute analytics
- represent the latest current status only

It remains event-oriented.

