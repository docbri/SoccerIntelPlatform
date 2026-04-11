# Staging Environment Terraform

## Purpose

Own the Staging environment infrastructure for the Soccer Intelligence Platform.

## First Real Slice

- resource group
- App Service plan
- Linux Web App for `Platform.Api`
- `staging` deployment slot

## Promotion Relationship

GitHub Actions deploys `Platform.Api` into the Terraform-created Staging slot.

