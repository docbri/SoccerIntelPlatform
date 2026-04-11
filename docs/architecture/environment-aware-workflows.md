# Environment-Aware Workflows

## Purpose

Describe how the initial GitHub Actions workflows represent promotion to Staging and Production.

## Environments

- `staging`
- `production`

## Current Workflow Shape

Each major lane has:
- validation on pull requests
- staging deployment placeholder on push to `main`
- production deployment placeholder on manual trigger

## Lanes

- .NET
- Terraform (aka. OpenTofu)
- Databricks
- Snowflake

## Principle

Validation and promotion are separate concerns.

Passing CI means the change is healthy enough to consider.
Promotion means the change is intentionally moved into an environment.

## Future Evolution

Later, placeholders will be replaced with:
- real deploy commands
- environment-specific auth
- secret retrieval
- approval gates for production

