# API Serving from Gold

## Purpose

Define the first application-serving pattern from the medallion architecture into `Platform.Api`.

## Serving Principle

The API reads from Gold, not from Bronze or Silver.

Gold is the consumer-ready layer and should be the serving boundary for read-oriented application use cases.

## First Use Case

Provide current league status through the API.

Example conceptual endpoint:

- `GET /league-status/current`
- optional filters:
  - `leagueId`
  - `season`

## Source Table

- `gold.current_league_status`

## API Service Boundary

Use a dedicated read service abstraction:

- `ILeagueStatusReadService`

This service owns:
- querying Gold data
- mapping Gold records into API contracts
- hiding Databricks SQL details from endpoints

## Initial Query Pattern

Read from `gold.current_league_status` and optionally filter by:
- `league_id`
- `season`

## Why Gold

Do not read Bronze or Silver directly from the API because:
- Bronze is raw and replay-oriented
- Silver is normalized and transformation-oriented
- Gold is consumer-ready and stable enough for serving

## Future Evolution

Possible future serving patterns:
- Databricks SQL warehouse access
- cached API responses
- synced operational serving tables for lower-latency app use cases

