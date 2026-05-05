# Snowflake Delivery Pattern

## Role

Snowflake receives curated data products from Databricks Gold for BI fulfillment and sharing.

## First Delivered Dataset

- `SOCCERINTEL_STAGING.GOLD.CURRENT_LEAGUE_STATUS`

## Delivery Mode

Initial mode:
- scheduled full refresh from Databricks
- overwrite current-state table contents

## Rationale

This table represents a current-state Gold product, so full refresh semantics are simple and appropriate for the first implementation.

## Future Evolution

Later enhancements may include:
- incremental delivery
- multiple curated datasets
- broader customer-facing sharing patterns

