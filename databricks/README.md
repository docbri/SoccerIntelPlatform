# Databricks Area

This directory contains the future Databricks implementation for the Soccer Intelligence Platform.

## Intended Layers

- `src/bronze` - raw ingestion from Kafka into Bronze tables
- `src/silver` - cleaned and normalized football domain data
- `src/gold` - curated analytics-ready outputs

## Current Status

Current focus is Bronze ingestion design for:

- Kafka topic input from `Platform.Worker`
- raw storage into `bronze.raw_ingestion_events`

See:

- `src/bronze/README.md`
- `src/bronze/bronze_raw_ingestion_events.py`
- `../docs/architecture/bronze-ingestion-contract.md`
