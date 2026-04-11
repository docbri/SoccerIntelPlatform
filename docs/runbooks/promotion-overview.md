# Promotion Overview

## Staging

Merge to `main` and let the relevant workflow deploy:
- infra changes through OpenTofu workflow
- app changes through .NET workflow
- Databricks changes through Databricks workflow
- Snowflake changes through Snowflake workflow

## Production

Promote only after:
- Staging validation is complete
- manual approval is granted
- environment-specific secrets and identities are confirmed

## Principle

Promote each concern independently.
Do not redeploy everything just because one area changed.

## Azure Staging Prerequisite Reminder

Before the first real Staging deployment can succeed, Azure must be prepared with:
- App Service target
- staging slot
- Entra app/service principal
- federated credential for GitHub OIDC
- deployment authorization on the target resources
