# Environment and Secrets Strategy

## Purpose

Define how configuration, identity, and secrets are handled across local development, Azure-hosted components, Databricks, and Snowflake.

## Environment Model

- `Development` = local only
- `Staging` = shared Azure environment
- `Production` = production

## Configuration Rule

### Non-secret configuration
Store in application configuration:
- topic names
- table names
- workspace URLs
- warehouse IDs
- catalog/schema names
- retry settings
- feature flags

### Secrets
Do not store in source control or committed configuration.

Examples:
- API keys
- Databricks access tokens
- Snowflake credentials
- connection secrets

## Secret Store

Cloud secret store:
- Azure Key Vault

Local development:
- placeholders in config
- real local secrets through environment variables or user secrets

## Identity Strategy

### Platform.Api
- Azure managed identity in cloud environments

### Databricks automation
- service principal or managed-identity aligned automation identity

### Snowflake access
- non-password programmatic auth
- first practical option: key-pair style auth material stored securely
- future option: workload identity federation

## Databricks Secret Strategy

Use Databricks secrets or Azure Key Vault-backed secret scopes for runtime secret consumption.

Do not embed secrets in notebooks, jobs, or repo files.

## Security Principle

Transform once, distribute many times, and authenticate services with dedicated machine identities.

