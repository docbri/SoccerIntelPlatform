# Local Quarantine Test

## Purpose

Validate that the Bronze consumer quarantines malformed Kafka messages without crashing.

## Steps

### Publish plain invalid text
```bash
echo 'this is not valid json' | docker exec -i redpanda rpk topic produce soccer.raw.ingestion.dev

