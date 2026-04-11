# CI/CD Promotion Model

## Purpose

Define how infrastructure, application code, Databricks assets, and Snowflake artifacts are validated and promoted across environments.

## Environment Path

- Development = local only
- Staging = shared cloud environment
- Production = production

## Promotion Principle

Use one monorepo with multiple focused pipelines rather than one giant pipeline.

## Pipelines

### Infrastructure pipeline
Owns:
- OpenTofu validation
- OpenTofu plan
- OpenTofu apply

Path trigger:
- `infra/**`

Current first implementation:
- validate Staging environment root
- generate a real Staging plan artifact on `main`
- keep Production apply as a gated placeholder

### Application pipeline
Owns:
- .NET restore
- build
- tests
- app deployment

Path triggers:
- `src/**`
- `tests/**`

### Databricks pipeline
Owns:
- Databricks asset validation
- Databricks deployment to Staging/Production

Path trigger:
- `databricks/**`

### Snowflake pipeline
Owns:
- Snowflake SQL / artifact deployment

Path trigger:
- `snowflake/**`

## Promotion Flow

- feature branches: PR validation only
- main branch: deploy to Staging
- Production: manual approval gate

## Identity and Secrets

- Azure auth in GitHub Actions should use OIDC where possible
- secrets should come from Azure Key Vault or other approved secret stores
- Databricks and Snowflake automation should use non-human identities

