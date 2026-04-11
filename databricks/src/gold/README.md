# Gold Layer

## Purpose

The Gold layer contains consumer-ready data products built from Silver.

For the Soccer Intelligence Platform, the first Gold target is:

- `gold.current_league_status`

## Source

- `silver.league_status_events`

## Responsibilities

- present the latest known status per league and season
- simplify consumption for dashboards and APIs
- preserve enough lineage for traceability

## Non-Goals

Gold does not:
- preserve full raw event history
- replace Silver normalization
- serve as the raw replay boundary

