# Platform Bring-Up (Staging)

## Purpose

Describe how to bring up, verify, resume, plan, and tear down the SoccerIntelPlatform staging platform from source control.

The public operational entry point is:

    ./scripts/platform.sh

Lower-level scripts such as `scripts/up-staging.sh`, `scripts/up-redpanda.sh`, `scripts/destroy-staging.sh`, and `scripts/destroy-redpanda.sh` are implementation details. Operators should use `platform.sh` unless they are intentionally debugging one subordinate script.

## Operational Model

The current staging lifecycle is:

    ./scripts/platform.sh plan
    ./scripts/platform.sh up
    ./scripts/platform.sh resume
    ./scripts/platform.sh verify
    ./scripts/platform.sh down

Meaning:

- `plan` generates a non-mutating staging OpenTofu plan.
- `up` reconciles staging infrastructure, Redpanda, Databricks bundle resources, the medallion job, and verification.
- `resume` does not recreate infrastructure. It redeploys/runs Databricks bundle resources and verifies the platform after idle runtime timeout.
- `verify` validates Azure platform resources, the Databricks bundle, and the expected Unity Catalog medallion objects.
- `down` tears down bundle resources, Redpanda, and staging infrastructure.

## Prerequisites

Required local tools:

- Azure CLI
- OpenTofu
- Databricks CLI
- Git

Required access:

- Azure subscription access
- Storage Blob Data Contributor access to the OpenTofu remote state backend after bootstrap
- Databricks workspace access for the operator running Databricks bundle and Unity Catalog verification commands

## 1. Authenticate to Azure

Run from any directory:

    az login
    az account set --subscription "Azure subscription 1"

## 2. Confirm Databricks CLI authentication

The platform scripts do not create or switch Databricks CLI profiles during normal lifecycle commands.

The staging workspace host is resolved from OpenTofu output when needed:

    cd infra/terraform/env/staging
    tofu output -raw databricks_workspace_url

A non-mutating authentication check from the repository root is:

    DATABRICKS_HOST="https://$(cd infra/terraform/env/staging && tofu output -raw databricks_workspace_url)" databricks catalogs get soccerintel_staging >/dev/null && echo "Databricks env-host auth OK"

If this fails, fix local Databricks CLI authentication explicitly before running platform lifecycle commands.

## 3. Bootstrap OpenTofu remote state

Run from the repository root:

    cd infra/terraform/bootstrap
    tofu init
    tofu apply

This creates the remote state foundation:

- Resource group: `rg-soccerintel-tfstate`
- Storage account: `soccerinteltfstate`
- Blob container: `tfstate`

## 4. Plan staging infrastructure

Run from the repository root:

    ./scripts/platform.sh plan

This delegates to the staging OpenTofu planning path and generates:

- `infra/terraform/env/staging/staging.tfplan`
- `infra/terraform/env/staging/staging-plan.txt`

The plan path is intentionally non-mutating. It should not deploy Databricks bundles, run jobs, apply grants, or recreate runtime services.

## 5. Bring up the staging platform

Run from the repository root:

    ./scripts/platform.sh up

This is the full staging bring-up path.

It performs the following high-level sequence:

- Applies/reconciles staging infrastructure.
- Resolves the Databricks workspace URL from OpenTofu output.
- Uses the current Databricks CLI authentication context with `DATABRICKS_HOST`.
- Applies Databricks Unity Catalog grants when the CI grant principal is available.
- Verifies the Unity Catalog catalog and schemas.
- Brings up Redpanda.
- Validates the Databricks bundle.
- Deploys the Databricks bundle.
- Runs the medallion bundle job.
- Verifies Azure platform resources, Databricks catalog, schemas, and medallion tables.

The Databricks bundle job currently runs:

- Bronze task
- Silver task
- Gold task

Expected successful task output includes:

    BRONZE INGESTION COMPLETE
    SILVER TRANSFORMATION COMPLETE
    GOLD TRANSFORMATION COMPLETE

## 6. Resume Databricks runtime work after idle timeout

Run from the repository root:

    ./scripts/platform.sh resume

Use `resume` when durable infrastructure already exists but the Databricks runtime path needs to be made usable again.

The current bundle uses job-cluster behavior, so `resume` does not start a long-lived all-purpose cluster. Instead, it:

- Validates the Databricks bundle.
- Deploys the bundle.
- Runs the medallion slice job.
- Verifies Azure platform resources, catalog, schemas, and tables.

Use `resume` instead of `up` when the platform exists and the goal is to re-run or re-wake the Databricks job path.

## 7. Verify platform state

Run from the repository root:

    ./scripts/platform.sh verify

Current verification checks:

- Azure CLI authentication
- Azure resource group: `rg-soccerintel-platform`
- Azure App Service: `app-soccerintel-platform-api`
- Azure App Service slot: `app-soccerintel-platform-api/staging`
- Redpanda VM: `vm-redpanda-staging`
- Redpanda public IP: `pip-redpanda`
- Databricks bundle validation
- Catalog: `soccerintel_staging`
- Schemas:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`
- Tables:
  - `soccerintel_staging.bronze.raw_ingestion_events`
  - `soccerintel_staging.silver.league_status_events`
  - `soccerintel_staging.gold.current_league_status`

Expected successful verification ends with:

    Platform verification completed.

## 8. Tear down staging

Run from the repository root:

    ./scripts/platform.sh down

This is the public teardown path.

It currently delegates to lower-level teardown behavior for:

- Databricks bundle resources, where applicable
- Redpanda
- Staging infrastructure

Do not call subordinate destroy scripts directly unless intentionally debugging a specific layer.

## Redpanda SSH Key Note

The Redpanda VM module expects an SSH public key at:

    ~/.ssh/id_rsa.pub

In `plan` mode, the staging script avoids generating a new SSH key when the Redpanda VM already exists. It reads the existing Redpanda public key from OpenTofu state and writes it to the expected public key path.

This prevents `tofu plan` from forcing an unnecessary Redpanda VM replacement due to an artificial SSH key change.

In `apply` mode, the staging script ensures an SSH key pair exists before applying infrastructure.

## Databricks Unity Catalog Grant Note

The staging apply path can apply Unity Catalog grants for the CI principal when `AZURE_CLIENT_ID` is present.

In GitHub Actions, `AZURE_CLIENT_ID` is supplied by the staging environment secrets.

Locally, if `AZURE_CLIENT_ID` is not set, the script skips grant mutation and continues verification using the current Databricks CLI authentication context.

The grants currently applied for the CI principal are:

- `USE CATALOG` on `soccerintel_staging`
- `USE SCHEMA` on `soccerintel_staging.bronze`
- `USE SCHEMA` on `soccerintel_staging.silver`
- `USE SCHEMA` on `soccerintel_staging.gold`

Storage credential and external location grant automation should only be added if a full rebuild proves it is required.

## Success Criteria

The staging platform is considered up when:

- `./scripts/platform.sh up` completes successfully
- Azure platform resource verification passes
- The Databricks bundle job terminates successfully
- Bronze, Silver, and Gold tasks complete
- `./scripts/platform.sh verify` completes successfully
- The expected medallion tables exist:
  - `soccerintel_staging.bronze.raw_ingestion_events`
  - `soccerintel_staging.silver.league_status_events`
  - `soccerintel_staging.gold.current_league_status`
