# Platform Bring-Up (Staging)

## Purpose

This runbook describes how to bring up the SoccerIntelPlatform staging infrastructure from source control using OpenTofu.

## Prerequisites

- Azure CLI installed
- OpenTofu installed
- Databricks CLI installed
- Azure subscription access
- Storage Blob Data Contributor access to the Terraform state storage account after bootstrap

## 1. Authenticate to Azure

Run from any directory:

```bash
az login
az account set --subscription "Azure subscription 1"
```

## 2. Bootstrap Terraform remote state

Run from the repository root:

```bash
cd infra/terraform/bootstrap
tofu init
tofu apply
```

This creates the remote state foundation:

- Resource group: `rg-soccerintel-tfstate`
- Storage account: `soccerinteltfstate`
- Blob container: `tfstate`

## 3. Deploy staging infrastructure

From `infra/terraform/bootstrap`, move to the staging environment:

```bash
cd ../env/staging
tofu init -reconfigure
tofu apply
```

This deploys the staging platform infrastructure, including:

- Azure resource group
- App Service Plan
- Linux Web App
- Web App staging slot
- Azure Databricks workspace
- Azure Databricks Access Connector
- ADLS Gen2 managed storage account
- Unity Catalog managed storage container
- Unity Catalog storage credential
- Unity Catalog external location
- Unity Catalog catalog: `soccerintel_staging`
- Unity Catalog schemas: `bronze`, `silver`, `gold`

## 4. Authenticate to Databricks CLI

Get the workspace URL from OpenTofu:

```bash
tofu output databricks_workspace_url
```

Then authenticate:

```bash
databricks auth login --host https://<workspace-url>
```

Example:

```bash
databricks auth login --host https://adb-xxxxxxxxxxxxxxxx.x.azuredatabricks.net
```

## 5. Verify Unity Catalog

```bash
databricks catalogs list
databricks schemas list soccerintel_staging
databricks external-locations list
databricks storage-credentials list
```

Expected project-managed objects:

- Catalog: `soccerintel_staging`
- Schemas:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`
- External location: `soccerintel-staging-storage`
- Storage credential: `soccerintel-staging-credential`

Databricks-managed objects whose names begin with `adb_` are expected and should not be deleted manually.

## 6. Validate Unity Catalog write access

In Databricks SQL Editor, run:

```sql
CREATE TABLE soccerintel_staging.bronze.test_table (id INT);
DROP TABLE soccerintel_staging.bronze.test_table;
```

If both statements succeed, the Unity Catalog storage path, storage credential, external location, access connector, and schema permissions are working.

## Success Criteria

The platform bring-up is complete when:

- `tofu apply` completes successfully in `infra/terraform/env/staging`
- `soccerintel_staging` exists
- `bronze`, `silver`, and `gold` schemas exist
- `soccerintel-staging-storage` exists
- `soccerintel-staging-credential` exists
- The Databricks SQL create/drop table validation succeeds
-
