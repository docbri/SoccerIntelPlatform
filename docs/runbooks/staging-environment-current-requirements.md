# Staging Environment Current Requirements

## Purpose

Capture the current staging environment requirements for Azure, GitHub Actions, Databricks, and Unity Catalog.

This document describes what must exist for `infra-ci` and the staging platform lifecycle scripts to work.

## Public Operational Entry Point

The public staging lifecycle command is:

    ./scripts/platform.sh

Current lifecycle commands:

    ./scripts/platform.sh plan
    ./scripts/platform.sh up
    ./scripts/platform.sh resume
    ./scripts/platform.sh verify
    ./scripts/platform.sh down

Lower-level scripts are implementation details unless debugging a specific layer.

## GitHub Environment: staging

### Secrets

The GitHub `staging` environment requires:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

These values are used by GitHub Actions for Azure OIDC login and by scripts when the CI identity must be granted access to Databricks Unity Catalog objects.

### Variables

The GitHub `staging` environment currently uses:

- `AZURE_WEBAPP_NAME`

## GitHub Actions Behavior

The current infrastructure workflow is:

    .github/workflows/terraform-ci.yml

The workflow remains intentionally thin.

Current behavior:

- `validate-staging` runs OpenTofu format, init, and validate.
- `plan-staging` calls the public platform script:

      ./scripts/platform.sh plan

The platform planning path delegates to the staging OpenTofu planning behavior and generates:

- `infra/terraform/env/staging/staging.tfplan`
- `infra/terraform/env/staging/staging-plan.txt`

The workflow uploads both files as the `staging-tofu-plan` artifact.

## Azure Identity

The GitHub Actions staging identity uses federated authentication.

Federated credential subject:

- `repo:docbri/SoccerIntelPlatform:environment:staging`

The staging app registration / service principal is:

- `github-soccerintel-staging`

## Azure RBAC

The GitHub Actions staging identity requires:

- App deployment permission for staging App Service work
- Storage Blob Data Contributor for remote state backend access

The remote state backend uses:

- Resource group: `rg-soccerintel-tfstate`
- Storage account: `soccerinteltfstate`
- Blob container: `tfstate`

## Databricks Workspace Access

The GitHub Actions staging identity must exist in Azure Databricks and be assigned to the staging workspace.

Databricks service principal:

- `ccf06960-31f2-4b6f-83a4-1cd77ebc8b52`

Staging workspace:

- `adb-soccerintel-staging`

This identity is used by `infra-ci` when OpenTofu refreshes Databricks Unity Catalog resources during `plan-staging`.

## Databricks Unity Catalog Access

The GitHub Actions staging identity must be able to refresh Unity Catalog objects managed by OpenTofu.

Required access includes:

- Visibility to the storage credential `soccerintel-staging-credential`
- Visibility to the external location `soccerintel-staging-storage`
- `USE CATALOG` on `soccerintel_staging`
- `USE SCHEMA` on:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`

## Current Scripted Grant Behavior

The staging apply path can apply the following Unity Catalog grants when `AZURE_CLIENT_ID` is available:

    GRANT USE CATALOG
    ON CATALOG `soccerintel_staging`
    TO `<AZURE_CLIENT_ID>`;

    GRANT USE SCHEMA
    ON SCHEMA `soccerintel_staging`.`bronze`
    TO `<AZURE_CLIENT_ID>`;

    GRANT USE SCHEMA
    ON SCHEMA `soccerintel_staging`.`silver`
    TO `<AZURE_CLIENT_ID>`;

    GRANT USE SCHEMA
    ON SCHEMA `soccerintel_staging`.`gold`
    TO `<AZURE_CLIENT_ID>`;

In GitHub Actions, `AZURE_CLIENT_ID` is supplied by the GitHub `staging` environment.

Locally, if `AZURE_CLIENT_ID` is absent, the script skips grant mutation and continues verification with the current Databricks CLI authentication context.

## Databricks Bundle Requirements

The Databricks bundle lives under:

    databricks/

The staging bundle target is:

    staging

The bundle job key is:

    medallion-slice

The platform lifecycle script owns the normal bundle flow:

    databricks bundle validate -t staging
    databricks bundle deploy -t staging
    databricks bundle run -t staging medallion-slice

Operators should normally run:

    ./scripts/platform.sh resume

or:

    ./scripts/platform.sh up

instead of running those Databricks commands manually.

## Expected Unity Catalog Objects

Expected project-managed objects:

- Catalog: `soccerintel_staging`
- Schemas:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`
- Tables:
  - `soccerintel_staging.bronze.raw_ingestion_events`
  - `soccerintel_staging.silver.league_status_events`
  - `soccerintel_staging.gold.current_league_status`
- External location: `soccerintel-staging-storage`
- Storage credential: `soccerintel-staging-credential`

Databricks-managed objects whose names begin with `adb_` are expected and should not be deleted manually.

## Known Remaining Gap

A full destroy and rebuild has not yet been proven end-to-end.

The scripted grant path currently covers catalog and schema usage grants for the CI principal. Storage credential and external location grant automation should only be added if a full rebuild proves it is required.
