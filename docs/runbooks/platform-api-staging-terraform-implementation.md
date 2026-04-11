# Platform.Api Staging Infrastructure Implementation

## Purpose

Capture the first real OpenTofu implementation slice for the `Platform.Api` staging deployment target.

## Implemented Resources

- resource group
- Linux App Service plan
- Linux Web App
- `staging` slot

## Next Validation Steps

- `tofu init`
- `tofu fmt -recursive`
- `tofu validate`

## Next Infrastructure Steps

- add outputs useful to CI/CD
- align GitHub Actions infrastructure workflow to `infra/terraform/env/staging`
- later add App Service settings for real cloud configuration
- later integrate Key Vault and managed identity
