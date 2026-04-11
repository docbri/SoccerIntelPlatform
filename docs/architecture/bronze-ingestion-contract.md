# Bronze Ingestion Contract

## Purpose

The Bronze layer stores raw ingestion events from Kafka with enough metadata to support:

- replay
- traceability
- source auditing
- later parsing into Silver

## Kafka Topic

Development topic:

- `soccer.raw.ingestion.dev`

Base topic pattern:

- `soccer.raw.ingestion`

## Incoming Kafka Message Shape

Kafka message value is a JSON serialization of `IngestionEnvelope`.

Example conceptual shape:

```json
{
  "SchemaVersion": "1.0",
  "Source": "api-football",
  "EntityType": "league-status",
  "LeagueId": 135,
  "LeagueName": "League-135",
  "Season": 2025,
  "CorrelationId": "guid",
  "FetchedAtUtc": "2026-04-09T20:28:07.811249Z",
  "Endpoint": "/status",
  "RequestKey": "status-135-2025",
  "SourceEntityId": "135",
  "PayloadJson": "{\"warning\":\"API key not configured\"}"
}
