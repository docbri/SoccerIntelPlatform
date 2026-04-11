# Remote State Activation Checklist

## Purpose

Track the steps required to turn Azure Blob Storage remote state on for the Staging environment.

## Checklist

- [x] Create `rg-soccerintel-tfstate`
- [x] Create storage account `soccerinteltfstate`
- [x] Create private container `tfstate`
- [x] Confirm backend key path: `soccerintel/staging/platform-api.tfstate`
- [x] Run `tofu init -reconfigure` in `infra/terraform/env/staging`
- [x] Confirm state is created in Azure Blob Storage

## Remaining Steps

- [ ] Update GitHub Actions workflow to initialize against the real backend
- [ ] Verify CI can access remote state successfully
- [ ] Treat remote backend as authoritative for shared Staging planning

## Principle

Remote state is activated only after backend storage exists and has been verified.

## Current Status

Local environment is using remote state.

Next milestone: CI/CD successfully initializes and plans using the same backend.

