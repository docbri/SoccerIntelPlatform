# Gold to Snowflake Publish Runbook

## Purpose

Describe the first operational pattern for publishing a curated Gold dataset from Databricks into Snowflake.

## Dataset

Source:
- `soccerintel_staging.gold.current_league_status`

Target:
- `SOCCERINTEL_STAGING.GOLD.CURRENT_LEAGUE_STATUS`

## Initial Mode

- scheduled publish
- overwrite current-state target table

## Operational Steps

1. Validate that `soccerintel_staging.gold.current_league_status` is up to date.
2. Run the Databricks publish job.
3. Confirm row count in Snowflake target table.
4. Confirm sample rows match the Databricks Gold source.
5. If publish fails, do not alter Databricks Gold ownership or semantics in Snowflake.

## Principle

Transform once in Databricks.
Deliver many times from curated outputs.

