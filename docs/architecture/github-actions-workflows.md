# GitHub Actions Workflows

## Purpose

Define the initial workflow set for the Soccer Intelligence Platform monorepo.

## Workflows

### dotnet-ci.yml
Validates:
- application code
- unit tests
- integration tests

Triggers:
- `src/**`
- `tests/**`

### terraform-ci.yml
Validates:
- OpenTofu formatting
- OpenTofu configuration syntax for the Staging environment root
- real Staging `tofu plan` artifact generation on `main`

Triggers:
- `infra/**`

### databricks-ci.yml
Validates:
- Databricks repository structure
- required Bronze/Silver/Gold artifacts

Triggers:
- `databricks/**`

### snowflake-ci.yml
Validates:
- Snowflake SQL artifacts
- Snowflake documentation structure

Triggers:
- `snowflake/**`

## Principle

The monorepo uses multiple focused workflows rather than one giant pipeline.

