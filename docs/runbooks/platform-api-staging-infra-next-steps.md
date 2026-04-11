# Platform.Api Staging Infrastructure Next Steps

## Purpose

Track the next implementation steps for making `Platform.Api` Staging hosting real in Terraform.

## Next Terraform Work

- define resource group variables
- define App Service plan variables
- define Linux Web App variables
- define staging slot variables
- add environment-specific values under `infra/terraform/env/staging`
- connect GitHub staging deployment workflow to the Terraform-created web app and slot

## Principle

Infrastructure should create the deployment target.
CI/CD should deploy to the created target.

