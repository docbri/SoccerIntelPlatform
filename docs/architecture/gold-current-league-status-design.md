# Gold Current League Status Design

## Purpose

Provide the latest known status for each league as a consumer-ready Gold data product.

This table is intended for:
- operational dashboards
- APIs
- monitoring and service views

## Source Table

- `silver.league_status_events`

## Target Table

- `gold.current_league_status`

## Grain

One row per:
- `league_id`
- `league_name`
- `season`

## Selection Rule

Choose the latest Silver event by `ingested_at_utc` for each league and season.

## Columns

### Identity and domain
- `league_id`
- `league_name`
- `season`

### Current status fields
- `api_status`
- `api_response_length`
- `api_warning`
- `status_category`

### Freshness and lineage
- `latest_idempotency_key`
- `latest_request_key`
- `latest_correlation_id`
- `latest_fetched_at_utc`
- `latest_ingested_at_utc`
- `event_date`

### Optional raw traceability
- `latest_payload_json`

## Status Category Rule

- if `api_warning` is populated, set `status_category = 'warning'`
- else if `api_status` is populated, set `status_category = 'ok'`
- else set `status_category = 'unknown'`

## Non-Goals

This Gold table does not:
- preserve all historical events
- replace Silver event history
- compute broad business analytics
- combine multiple entity types

