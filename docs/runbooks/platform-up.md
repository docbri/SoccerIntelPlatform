# Platform Bring-Up (Staging)

## Purpose

Describe how to bring up the SoccerIntelPlatform staging infrastructure from source control using OpenTofu.

## Prerequisites

- Azure CLI installed
- OpenTofu installed
- Databricks CLI installed
- Azure subscription access
- Storage Blob Data Contributor access to the Terraform state storage account after bootstrap
- Databricks workspace access for the operator running Unity Catalog verification

## 1. Authenticate to Azure

Run from any directory:

    az login
    az account set --subscription "Azure subscription 1"

## 2. Bootstrap Terraform remote state

Run from the repository root:

    cd infra/terraform/bootstrap
    tofu init
    tofu apply

This creates the remote state foundation:

- Resource group: `rg-soccerintel-tfstate`
- Storage account: `soccerinteltfstate`
- Blob container: `tfstate`

## 3. Plan staging infrastructure

Run from the repository root:

    ./scripts/up-staging.sh plan

This initializes the staging OpenTofu root and generates:

- `infra/terraform/env/staging/staging.tfplan`
- `infra/terraform/env/staging/staging-plan.txt`

The script resolves the staging OpenTofu root as:

    infra/terraform/env/staging

## 4. Deploy staging infrastructure

Run from the repository root:

    ./scripts/up-staging.sh apply

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

## 5. Databricks authentication

The `apply` mode resolves the Databricks workspace URL from OpenTofu output:

    tofu output -raw databricks_workspace_url

Then it authenticates the Databricks CLI:

    databricks auth login --host https://<workspace-url>

The script derives the Databricks CLI profile name from the workspace URL and switches that profile to default.

## 6. Verify Unity Catalog

The `apply` mode verifies Unity Catalog by running:

    databricks catalogs list
    databricks schemas list soccerintel_staging

Additional manual checks may include:

    databricks external-locations list
    databricks storage-credentials list

Expected project-managed objects:

- Catalog: `soccerintel_staging`
- Schemas:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`
- External location: `soccerintel-staging-storage`
- Storage credential: `soccerintel-staging-credential`

Databricks-managed objects whose names begin with `adb_` are expected and should not be deleted manually.

## 7. Validate Unity Catalog write access

In Databricks SQL Editor, run:

    CREATE TABLE soccerintel_staging.bronze.test_table (id INT);
    DROP TABLE soccerintel_staging.bronze.test_table;

If both statements succeed, the Unity Catalog storage path, storage credential, external location, access connector, and schema permissions are working.

## Redpanda SSH Key Note

The Redpanda VM module expects an SSH public key at:

    ~/.ssh/id_rsa.pub

In `plan` mode, `scripts/up-staging.sh` avoids generating a new SSH key when the Redpanda VM already exists. It reads the existing Redpanda public key from OpenTofu state and writes it to the expected public key path.

This prevents `tofu plan` from forcing an unnecessary Redpanda VM replacement due to an artificial SSH key change.

In `apply` mode, the script ensures an SSH key pair exists before applying infrastructure.

## Success Criteria

The platform bring-up is complete when:

- `./scripts/up-staging.sh apply` completes successfully
- `soccerintel_staging` exists
- `bronze`, `silver`, and `gold` schemas exist
- `soccerintel-staging-storage` exists
- `soccerintel-staging-credential` exists
- The Databricks SQL create/drop table validation succeeds
