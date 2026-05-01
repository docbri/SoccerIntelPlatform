# Staging Environment Current Requirements

## GitHub Environment: staging

### Secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Variables

- `AZURE_WEBAPP_NAME`

## Azure Identity

Federated credential subject:

- `repo:docbri/SoccerIntelPlatform:environment:staging`

## Azure RBAC

The GitHub Actions staging identity requires:

- App deployment permission for `github-soccerintel-staging`
- Storage Blob Data Contributor for remote state backend access

## Databricks Workspace Access

The GitHub Actions staging identity must exist in Azure Databricks and be assigned to the staging workspace.

Databricks service principal:

- `ccf06960-31f2-4b6f-83a4-1cd77ebc8b52`

Staging workspace:

- `adb-soccerintel-staging`

This identity is used by `infra-ci` when OpenTofu refreshes Databricks Unity Catalog resources during `plan-staging`.

## Databricks Unity Catalog Access

The GitHub Actions staging identity must be able to refresh the Unity Catalog objects managed by OpenTofu.

Required access includes:

- visibility to the storage credential `soccerintel-staging-credential`
- visibility to the external location `soccerintel-staging-storage`
- `USE CATALOG` on `soccerintel_staging`
- `USE SCHEMA` on:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`

The schema grants used during CI stabilization were:

```sql
GRANT USE SCHEMA
ON SCHEMA `soccerintel_staging`.`bronze`
TO `ccf06960-31f2-4b6f-83a4-1cd77ebc8b52`;

GRANT USE SCHEMA
ON SCHEMA `soccerintel_staging`.`silver`
TO `ccf06960-31f2-4b6f-83a4-1cd77ebc8b52`;

GRANT USE SCHEMA
ON SCHEMA `soccerintel_staging`.`gold`
TO `ccf06960-31f2-4b6f-83a4-1cd77ebc8b52`;
