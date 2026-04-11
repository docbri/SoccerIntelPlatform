# Databricks Statement Execution Client

## Purpose

Define the real API-side infrastructure client for running SQL against Databricks SQL warehouses.

## Runtime Pattern

- `Platform.Api`
- `LeagueStatusReadService`
- `IDatabricksSqlClient`
- `DatabricksStatementExecutionSqlClient`
- Databricks Statement Execution API
- SQL warehouse
- Gold table

## Why This Pattern

Databricks SQL queries execute on a SQL warehouse.
Programmatic execution is handled through the Statement Execution API.

## Required Configuration

- `WorkspaceUrl`
- `WarehouseId`
- `Catalog`
- `Schema`
- `AuthenticationType`
- `AccessToken`

## Security Notes

The calling identity must:
- be authenticated to Azure Databricks
- have permission to use the target SQL warehouse
- have permission to read the referenced Gold tables

## Local Development Strategy

Keep using `StubDatabricksSqlClient` while:
- no real warehouse exists
- no real auth is configured
- local architecture and contracts are still being shaped

## Next Implementation Steps

- add typed response models for Statement Execution API responses
- parse `JSON_ARRAY` row results
- map rows into `DatabricksSqlRow`
- choose auth mode for non-local environments

