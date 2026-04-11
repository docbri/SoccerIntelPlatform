# Databricks SQL Service Boundary

## Purpose

Define the API-side infrastructure boundary for reading Gold data from Databricks SQL.

## Layers

- API endpoint
- application read service
- Databricks SQL client abstraction

## Current Shape

- `ILeagueStatusReadService`
- `LeagueStatusReadService`
- `IDatabricksSqlClient`
- `StubDatabricksSqlClient`

## Why This Boundary Exists

The API should not:
- embed Databricks SQL execution details in endpoints
- map Gold rows directly in endpoints
- depend directly on warehouse-specific mechanics

The read service owns:
- query intent
- query filtering
- mapping infrastructure rows into API contracts

The Databricks SQL client owns:
- actual SQL execution mechanics

## Future Evolution

Later, replace `StubDatabricksSqlClient` with a real implementation that:
- authenticates to Databricks
- executes SQL against a warehouse
- maps query results into `DatabricksSqlRow`

