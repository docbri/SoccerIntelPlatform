# Gold to Snowflake Handoff

## Purpose

Define the first curated data handoff from the Databricks-centered platform core into Snowflake as a customer-facing BI and data-sharing layer.

## Ownership Model

- Databricks owns ingestion, transformation, and curation
- Snowflake owns downstream fulfillment and sharing
- Gold is the handoff boundary

## First Handoff Dataset

Databricks source:

- `soccerintel_staging.gold.current_league_status`

Snowflake target:

- `SOCCERINTEL_STAGING.GOLD.CURRENT_LEAGUE_STATUS`

## Handoff Principle

Snowflake receives curated data products, not raw ingestion data and not transformation logic.

## Contract Shape

### Identity and domain
- `league_id`
- `league_name`
- `season`

### Current status
- `status_category`
- `api_status`
- `api_warning`

### Freshness and lineage
- `latest_idempotency_key`
- `latest_request_key`
- `latest_correlation_id`
- `latest_fetched_at_utc`
- `latest_ingested_at_utc`
- `event_date`

### Optional traceability
- `latest_payload_json`

## Semantic Guarantees

- one row per `league_id` and `season`
- row represents the latest known current status
- status derivation is already complete before handoff
- lineage fields remain available for traceability

## Delivery Style

Initial posture:
- scheduled curated sync
- current-state snapshot style
- not raw event replication
- not parallel Bronze/Silver/Gold in Snowflake

## Why This Boundary Exists

The platform should transform once and distribute many times.

Databricks is the transformation core.
Snowflake is the curated fulfillment and sharing layer.

