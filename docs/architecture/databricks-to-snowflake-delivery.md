# Databricks to Snowflake Delivery

## Purpose

Define how curated Gold datasets are delivered from Databricks into Snowflake in this project.

## First Delivery Target

Databricks source:
- `gold.current_league_status`

Snowflake target:
- `SOCCER_INTEL.CURATED.CURRENT_LEAGUE_STATUS`

## Delivery Principle

Transformation happens in Databricks.
Distribution happens in Snowflake.

Snowflake receives a curated dataset, not raw data and not transformation instructions.

## Initial Delivery Pattern

- scheduled Databricks job
- Spark reads `gold.current_league_status`
- Snowflake Spark Connector writes the dataset to Snowflake
- first version uses full refresh / overwrite semantics

## Why This Pattern

This keeps:
- Databricks as the transformation core
- Snowflake as the curated fulfillment layer
- a single authoritative transformation path

## Non-Goals

This delivery path does not:
- replicate Bronze or Silver to Snowflake
- create a second medallion implementation in Snowflake
- stream every raw event into Snowflake

## Future Evolution

Possible future enhancements:
- incremental merge delivery
- multiple Gold datasets
- governed sharing patterns
- customer-specific Snowflake data products

