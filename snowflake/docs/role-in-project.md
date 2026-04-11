# Snowflake Role in This Project

## Role

Snowflake is the customer-facing BI fulfillment and curated data-sharing layer.

It is not the transformation core of this project.

## Upstream Source

Curated datasets arrive from Databricks Gold outputs.

## First Target Dataset

- `SOCCER_INTEL.CURATED.CURRENT_LEAGUE_STATUS`

## Responsibilities

- support downstream BI consumption
- support easier dataset sharing
- expose curated, governed outputs

## Non-Goals

Snowflake does not:
- own Bronze ingestion
- own Silver normalization
- duplicate the entire medallion pipeline
- replace Databricks as the platform core in this project

