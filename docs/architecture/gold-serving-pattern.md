# Gold Serving Pattern

## Purpose

Describe how Gold data products are intended to be served to applications and BI consumers.

## Current Recommended Pattern

- Gold tables are queried through Databricks SQL / SQL warehouses
- BI tools such as Power BI read curated Gold outputs through Databricks SQL
- application services can also use Gold as the read boundary

## First Gold Serving Target

- `gold.current_league_status`

## Why This Pattern

Gold is intended to be:
- business-ready
- consumer-oriented
- stable enough for downstream use
- performance-tuned for frequent queries

## Future Considerations

If application latency or concurrency requirements exceed what is appropriate for direct analytical serving, consider a downstream operational serving path such as synced serving tables or an operational store derived from Gold.

