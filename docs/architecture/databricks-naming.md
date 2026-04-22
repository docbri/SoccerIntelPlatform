# Databricks Naming Contract

## Purpose

Define the canonical naming model for Databricks and Unity Catalog in SoccerIntelPlatform.

This document is the source of truth for:

- environment naming
- Azure resource naming intent
- Unity Catalog naming
- medallion placement
- API query expectations

---

## Naming Rule by System

Use the naming style native to the system you are working in.

### Azure resource names

Use dash-separated names.

Examples:

- `rg-soccerintel-platform`
- `asp-soccerintel-platform`
- `app-soccerintel-platform-api`
- `adb-soccerintel-staging`
- `ac-soccerintel-staging`

Reason:

Azure resource names are human-facing cloud resource identifiers, and dash-separated naming is the normal readable convention there.

### Databricks / Unity Catalog / SQL object names

Use underscore-separated names.

Examples:

- `soccerintel_staging`
- `bronze`
- `silver`
- `gold`
- `raw_ingestion_events`
- `league_status_events`
- `current_league_status`

Reason:

SQL-style systems and Unity Catalog use names that should be safe and convenient in `catalog.schema.object` references. Underscores avoid quoting problems that dashes would introduce.

### Terraform variable names

Use snake_case.

Examples:

- `resource_group_name`
- `databricks_catalog_name`
- `databricks_workspace_name`

Reason:

That is the native style of Terraform variables.

---

## Environment Model

Logical environments:

- `staging`
- `production`

Do not introduce extra Databricks-only environment variants such as:

- `devlake`
- `analytics-staging`
- `uc-staging`

The Databricks environment model should stay aligned to the rest of the platform.

---

## Unity Catalog Structure

### Catalogs (environment/platform boundary)

- `soccerintel_staging`
- `soccerintel_production` later

Rule:

Catalog represents the environment-scoped platform namespace.

### Schemas (medallion boundary)

Inside each catalog:

- `bronze`
- `silver`
- `gold`

Examples:

- `soccerintel_staging.bronze`
- `soccerintel_staging.silver`
- `soccerintel_staging.gold`

Rule:

Schemas represent medallion layers, not environments.

---

## First-Slice Objects

### Bronze

- `soccerintel_staging.bronze.raw_ingestion_events`
- `soccerintel_staging.bronze.raw_ingestion_quarantine`

### Silver

- `soccerintel_staging.silver.league_status_events`

### Gold

- `soccerintel_staging.gold.current_league_status`

---

## Naming Rules

### Rule 1 — Always fully qualify in Databricks and SQL-facing code

Always use:

`catalog.schema.object`

Example:

`soccerintel_staging.gold.current_league_status`

Never use:

- `gold.current_league_status`
- `current_league_status`

Reason:

Fully qualified references avoid ambiguity and keep the API portable across staging and production.

### Rule 2 — Do not encode environment in table names

Avoid:

- `staging_current_league_status`
- `prod_league_status_events`

Reason:

Environment belongs at the catalog layer.

### Rule 3 — Do not use medallion layer names as catalogs

Invalid:

- catalog = `gold`
- catalog = `bronze`

Correct:

- catalog = `soccerintel_staging`
- schema = `gold`

---

## Gold Serving Model

Gold objects are Unity Catalog managed Delta tables for this phase.

Primary serving object:

`soccerintel_staging.gold.current_league_status`

Gold is:

- a managed Delta table
- not a standard view
- not a materialized view for this phase

---

## API Contract

The API must query using:

`{Catalog}.{Schema}.{Object}`

Example:

`soccerintel_staging.gold.current_league_status`

Configuration must supply:

- `Catalog`
- `Schema`
- `CurrentLeagueStatusObjectName`

The API must not hardcode Unity Catalog object names.

---

## First Slice Scope

This naming model applies to the first realized Databricks slice:

- Bronze ingestion
- Silver transformation
- Gold serving
- API consumption via Databricks SQL

---

## Out of Scope

This document does not define:

- SQL warehouse sizing
- authentication strategy
- deployment tooling details
- exact Azure runtime/compute settings

Those are defined in later sections.
