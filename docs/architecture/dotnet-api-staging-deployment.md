# .NET API Staging Deployment

## Purpose

Define the first real deployment lane for the Soccer Intelligence Platform.

## First Real Deployment Target

- `Platform.Api`
- Azure App Service
- Staging deployment slot

## CI/CD Flow

1. Build and test the .NET solution
2. Publish `Platform.Api`
3. Authenticate from GitHub Actions to Azure using OIDC
4. Deploy the published output to the App Service staging slot

## Why This Lane First

This is the simplest end-to-end deployment path in the project and proves:
- environment-aware promotion
- GitHub Actions deployment structure
- Azure authentication shape
- app artifact deployment

## Non-Goals

This step does not:
- deploy the Worker
- deploy Databricks assets
- deploy Snowflake artifacts
- replace Terraform as the infrastructure owner

## Security Model

- use GitHub Actions OIDC for Azure authentication
- avoid long-lived Azure deployment secrets in GitHub
- keep environment-specific configuration and secrets outside source control

