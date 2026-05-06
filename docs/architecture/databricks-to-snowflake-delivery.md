# Databricks to Snowflake Delivery

## Purpose

Define how curated Gold datasets are prepared for delivery from Databricks into Snowflake in this project.

## Current Posture

The project is Snowflake-enabled and subscription-ready, but Snowflake publication is not active by default.

The repository already contains the Snowflake publication contract, target SQL, foundation SQL template, key-pair authentication-ready Databricks publish script, and ready-to-enable Databricks task snippet.  A Snowflake subscription/account is the remaining boundary before runtime publication can be activated.

The active staging medallion path remains:

- Bronze ingestion
- Silver normalization
- Gold current-state projection

Snowflake publication is intentionally held behind a subscription/runtime boundary so the current Azure/Databricks platform remains runnable without Snowflake spend or credentials.

## First Delivery Target

Databricks source:

- `soccerintel_staging.gold.current_league_status`

Snowflake target:

- `SOCCERINTEL_STAGING.GOLD.CURRENT_LEAGUE_STATUS`

## Delivery Principle

Transformation happens in Databricks.
Distribution happens in Snowflake.

Snowflake receives a curated dataset, not raw data and not transformation instructions.

## Prepared Delivery Pattern

When Snowflake is activated:

- a Snowflake account is provisioned
- the Snowflake foundation SQL template is rendered with the service user's public key
- the foundation SQL is applied to create the database, schema, warehouse, role, service user, and target table
- Databricks secrets are populated with Snowflake key-pair connection values
- the Snowflake publish task example is added to the active Databricks job after Gold
- Spark reads `soccerintel_staging.gold.current_league_status`
- the Snowflake Spark Connector writes the dataset to Snowflake
- the first version uses full refresh / overwrite semantics

## Why This Pattern

This keeps:

- Databricks as the transformation core
- Snowflake as the curated fulfillment layer
- a single authoritative transformation path
- the current Azure/Databricks staging flow runnable without requiring a Snowflake subscription

## Non-Goals

This delivery path does not:

- require Snowflake for the default staging medallion run
- replicate Bronze or Silver to Snowflake
- create a second medallion implementation in Snowflake
- stream every raw event into Snowflake

## Future Activation

Possible future enhancements after Snowflake activation:

- active Gold-to-Snowflake publication task
- incremental merge delivery
- multiple Gold datasets
- governed sharing patterns
- customer-specific Snowflake data products
