# Platform.Api Staging OpenTofu Shape

## Purpose

Define the first OpenTofu-owned Azure resource shape for real Staging deployment of `Platform.Api`.

## Target Shape

- one resource group
- one Linux App Service plan
- one Linux Web App for `Platform.Api`
- one `staging` slot on the web app

## Why This Shape

This is the smallest realistic Azure hosting footprint that supports:
- GitHub Actions deployment
- Staging validation
- future production promotion by slot swap or direct production deployment

## Scope

This first OpenTofu slice covers:
- hosting resources for `Platform.Api`
- Staging slot
- non-secret application settings placeholders

It does not yet cover:
- Worker hosting
- Key Vault integration
- networking
- Databricks infrastructure
- Snowflake integration infrastructure

## Promotion Model

- deploy to staging slot first
- validate staging
- later promote toward production

