# Azure Staging Prerequisites

## Purpose

Define the Azure-side prerequisites required for the first real Staging deployment lane for `Platform.Api`.

## Deployment Target

- Azure App Service web app
- staging deployment slot

## Required Azure Objects

- App Service plan
- App Service web app
- staging slot on the web app
- Microsoft Entra app registration
- service principal for that app registration
- federated credential that trusts the GitHub repository/workflow context

## Required GitHub Staging Environment Values

### Secrets
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Variables
- `AZURE_WEBAPP_NAME`

## Required Permissions

The automation identity must be authorized to deploy to the target App Service resources.

## Trust Model

GitHub Actions authenticates to Azure using OIDC through `azure/login`.
No long-lived Azure credential secret should be required in GitHub for this lane.

## Scope

This prerequisite checklist applies only to:
- `Platform.Api`
- Staging
- Azure App Service slot deployment

It does not yet cover:
- Worker deployment
- Databricks deployment
- Snowflake deployment
- Production promotion

