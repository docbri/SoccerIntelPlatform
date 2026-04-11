# Silver Layer

## Purpose

The Silver layer contains validated, cleaned, typed, and deduplicated data built from Bronze.

For the Soccer Intelligence Platform, the first Silver target is:

- `silver.league_status_events`

## Source

- `bronze.raw_ingestion_events`

## Responsibilities

- validate fields again at the Silver boundary
- parse `payload_json`
- deduplicate by `idempotency_key`
- preserve enough raw data for traceability

## Non-Goals

Silver does not:
- compute reporting aggregates
- act as the final BI layer
- replace Gold summaries

