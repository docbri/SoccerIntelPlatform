# GitHub to Azure OIDC Trust

## Purpose

Describe the trust relationship required for GitHub Actions to authenticate to Azure without long-lived Azure credentials.

## Model

- GitHub Actions issues an OIDC token
- Azure trusts that token through a federated credential on a Microsoft Entra app registration
- the workflow uses `azure/login` with:
  - client ID
  - tenant ID
  - subscription ID

## Result

The GitHub workflow can authenticate to Azure and deploy to the target App Service if the Azure-side trust and RBAC permissions are configured correctly.

## Why This Matters

This reduces secret sprawl and aligns deployment automation with short-lived identity tokens instead of stored cloud credentials.

