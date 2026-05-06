# Gold to Snowflake Publish Runbook

## Purpose

Describe how the first curated Gold dataset will be published from Databricks into Snowflake once a Snowflake subscription is available.

## Current Status

Snowflake publication is wired and prepared, but not active by default.

The project is intentionally waiting on a Snowflake subscription/account before runtime publication is enabled.  The repository already includes the code, SQL templates, and Databricks task shape needed to activate Gold-to-Snowflake fulfillment once that subscription exists.

The project currently includes:

- Snowflake target table SQL
- Snowflake foundation SQL template
- key-pair authentication-ready Databricks publish script
- Databricks task example for enabling the publish step later

The default staging medallion job still ends at Databricks Gold so the platform remains fully runnable without a Snowflake account.

## Dataset

Source:

- `soccerintel_staging.gold.current_league_status`

Target:

- `SOCCERINTEL_STAGING.GOLD.CURRENT_LEAGUE_STATUS`

## Initial Mode After Activation

- scheduled publish
- overwrite current-state target table
- key-pair authentication from Databricks to Snowflake

## Activation Prerequisites

Before enabling the publish task:

1. Create or subscribe to Snowflake.
2. Render `snowflake/sql/staging_foundation.sql` with the service user's public key.
3. Apply the rendered foundation SQL in Snowflake.
4. Create the Databricks secret scope `soccerintel-staging-snowflake`.
5. Store Snowflake runtime values in that scope:
   - `url`
   - `user`
   - `private_key`
   - `role`
   - `warehouse`
6. Add the task from `databricks/resources/snowflake_publish_task.example.txt` to the active Databricks job after Gold.
7. Validate the Databricks bundle.

## Operational Steps After Activation

1. Validate that `soccerintel_staging.gold.current_league_status` is up to date.
2. Run the Databricks medallion job.
3. Confirm row count in Snowflake target table.
4. Confirm sample rows match the Databricks Gold source.
5. If publish fails, do not alter Databricks Gold ownership or semantics in Snowflake.

## Principle

Transform once in Databricks.
Deliver many times from curated outputs.
