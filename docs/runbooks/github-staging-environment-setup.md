# GitHub Staging Environment Setup

## Purpose

Describe the minimum GitHub environment configuration required for real Staging deployment of `Platform.Api`.

## Environment Name

- `staging`

## Required Secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Required Variables

- `AZURE_WEBAPP_NAME`

## Notes

The workflow uses GitHub Actions OIDC with Azure login.

The Azure side must be configured to trust the GitHub repository/workflow as a federated identity before deployment will succeed.

The deployment target is the App Service staging slot for the configured web app.

