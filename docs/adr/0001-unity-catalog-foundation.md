# ADR-0001 — Unity Catalog Foundation Strategy

## Status

Accepted

---

## Context

SoccerIntelPlatform is introducing Azure Databricks with Unity Catalog as the
data platform control plane.

At this stage, we are implementing the first end-to-end slice:

- Bronze ingestion
- Silver transformation
- Gold serving
- API consumption via Databricks SQL

We must define:

- how environments are isolated
- how storage is managed
- how Unity Catalog is structured
- how permissions are simplified for the first phase

These decisions will strongly influence future scalability, governance, and cost.

---

## Decision

### 1. Metastore Strategy

Use a single regional Unity Catalog metastore.

- The staging workspace is attached to this metastore
- Future production workspace will also attach to the same regional metastore

Environment isolation is NOT done at the metastore level.

---

### 2. Environment Isolation Model

Environment separation is implemented at the catalog level.

- staging catalog: `soccerintel_staging`
- production catalog: `soccerintel_production` (future)

---

### 3. Namespace Structure

Unity Catalog namespace follows:

- catalog → environment/platform boundary
- schema → medallion layer
- object → business data artifact

Schemas:

- `bronze`
- `silver`
- `gold`

---

### 4. Storage Strategy

Use Unity Catalog managed storage backed by ADLS Gen2.

- Storage account provisioned via OpenTofu (Section B)
- Access Connector managed identity used for access
- No external tables in this phase

All first-slice tables are:

- Unity Catalog managed Delta tables

---

### 5. Data Layer Placement

Bronze:

- `soccerintel_staging.bronze.raw_ingestion_events`
- `soccerintel_staging.bronze.raw_ingestion_quarantine`

Silver:

- `soccerintel_staging.silver.league_status_events`

Gold:

- `soccerintel_staging.gold.current_league_status`

---

### 6. Ownership Model (Phase 1)

Use a simplified ownership model:

- single platform owner for catalog and schemas
- no domain-level ownership separation yet

---

### 7. Permission Model (Phase 1)

Define four role types:

1. Platform Admin
2. Pipeline Writer
3. API Read Identity
4. Human Operator

Keep permissions minimal and aligned to:

- build
- write
- read
- troubleshoot

No advanced RBAC model in this phase.

---

### 8. API Contract Dependency

The API will read from:

soccerintel_staging.gold.current_league_status

This fully qualified Unity Catalog name is now a stable contract.

---

## Consequences

### Positive

- Simple, correct Unity Catalog implementation
- Low operational complexity
- Clear separation of concerns
- Minimal cost overhead
- No premature governance complexity

---

### Negative

- Limited flexibility for multi-team ownership
- Simplified permissions may need refactoring later
- Single metastore model assumes future compatibility across environments

---

### Neutral / Deferred

The following are intentionally deferred:

- production catalog rollout
- advanced RBAC and domain ownership
- external tables and external locations
- Unity Catalog volumes beyond immediate need
- cross-workspace sharing
- lineage-driven governance workflows

---

## Alternatives Considered

### Separate metastores per environment

Rejected because:

- increases control-plane complexity
- unnecessary for current scale
- not aligned with Unity Catalog regional model

---

### External tables for Bronze/Silver/Gold

Rejected because:

- increases storage complexity
- unnecessary for first implementation
- not aligned with managed-table-first approach

---

### Early full RBAC model

Rejected because:

- adds complexity without immediate benefit
- slows down initial platform realization

---

## Notes

This ADR captures the Unity Catalog strategy for the first Databricks phase.

Future ADRs may refine:

- production rollout strategy
- governance model evolution
- data sharing and access patterns

