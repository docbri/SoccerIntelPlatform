# Databricks Naming Contract (Section A)

## Purpose

Define the canonical naming model for Unity Catalog and Databricks objects in SoccerIntelPlatform.

This document is the source of truth for:
- environment naming
- Unity Catalog structure
- medallion placement
- API query expectations

---

## Environment Model

Logical environments:

- staging
- production

No additional environment variants are introduced (e.g., devlake, analytics, etc.).

---

## Unity Catalog Structure

### Catalogs (environment boundary)

- staging_soccerintel
- production_soccerintel (future)

Rule:
Catalog represents the environment-scoped platform namespace.

---

### Schemas (medallion boundary)

Inside each catalog:

- bronze
- silver
- gold

Examples:

- staging_soccerintel.bronze
- staging_soccerintel.silver
- staging_soccerintel.gold

Rule:
Schemas represent medallion layers, not environments.

---

### Tables (business objects)

Bronze:

- staging_soccerintel.bronze.raw_ingestion_events
- staging_soccerintel.bronze.raw_ingestion_quarantine

Silver:

- staging_soccerintel.silver.league_status_events

Gold:

- staging_soccerintel.gold.current_league_status

---

## Naming Rules

### Rule 1 — Always fully qualify

Always use:

catalog.schema.object

Example:

staging_soccerintel.gold.current_league_status

Never use:

- gold.current_league_status
- current_league_status

---

### Rule 2 — Do not encode environment in table names

Avoid:

- staging_current_league_status
- prod_league_status_events

Environment belongs at the catalog level.

---

### Rule 3 — Do not use catalogs for medallion layers

Invalid:

- catalog = gold
- catalog = bronze

Correct:

- catalog = staging_soccerintel
- schema = gold

---

## Gold Serving Model

- Gold objects are **Unity Catalog managed Delta tables**
- Not standard views
- Not materialized views (for this phase)

Primary serving object:

staging_soccerintel.gold.current_league_status

---

## API Contract

The API must query using:

{Catalog}.{Schema}.{Object}

Example:

staging_soccerintel.gold.current_league_status

Configuration must supply:

- Catalog
- Schema
- Object name

The API must not hardcode table names.

---

## First Slice Scope

This naming model applies to the first realized slice:

- Bronze ingestion
- Silver transformation
- Gold serving
- API consumption via Databricks SQL

---

## Out of Scope

Not defined here:

- Azure resource naming
- SQL warehouse sizing
- authentication strategy
- deployment tooling

These are defined in later sections.

