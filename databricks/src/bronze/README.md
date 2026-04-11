# Bronze Layer

## Purpose

The Bronze layer stores raw ingestion events from Kafka with minimal transformation.

For the Soccer Intelligence Platform, Bronze ingestion will:

- read Kafka messages from `soccer.raw.ingestion*`
- parse the outer `IngestionEnvelope`
- preserve Kafka metadata
- preserve raw payload and raw transport message
- append valid rows to `bronze.raw_ingestion_events`
- append invalid rows to `bronze.raw_ingestion_quarantine`

## Tables

- `bronze.raw_ingestion_events`
- `bronze.raw_ingestion_quarantine`

## Core Rule

Bronze preserves reality before interpretation.

It does not:
- deeply parse football semantics
- compute analytics
- replace Silver normalization

## Files

- `bronze_raw_ingestion_events_sql.sql`
- `bronze_raw_ingestion_quarantine_sql.sql`
- `bronze_ingestion_flow.py`
- `bronze_kafka_to_delta.py`
