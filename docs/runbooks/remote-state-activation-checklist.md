# Remote State Activation Checklist

## Purpose

Track the steps required to turn Azure Blob Storage remote state on for the Staging environment.

## Checklist

- [x] Create `rg-soccerintel-tfstate`
- [x] Create storage account `soccerinteltfstate`
- [x] Create private container `tfstate`
- [x] Confirm backend key path: `soccerintel/staging/platform-api-v2.tfstate`
- [x] Run `tofu init -reconfigure` in `infra/terraform/env/staging`
- [x] Confirm state is created in Azure Blob Storage
- [x] Update GitHub Actions workflow to initialize against the real backend
- [x] Verify CI can access remote state successfully
- [x] Treat remote backend as authoritative for shared Staging planning

## Principle

Remote state is activated only after backend storage exists and has been verified.

## Current Status

Local development and CI/CD both initialize and plan using the shared Azure Blob remote state backend.

The `infra-ci` workflow is green for:

- `validate-staging`
- `plan-staging`

## Notes

The remote backend is now authoritative for shared Staging infrastructure planning.

OpenTofu plan refresh depends on both Azure RBAC and Databricks Unity Catalog permissions because the Staging state includes Azure resources and Databricks Unity Catalog resources.
