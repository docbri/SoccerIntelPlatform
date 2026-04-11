# Remote State Strategy

## Purpose

Define how OpenTofu state is stored for shared environments.

## Backend Pattern

Use Azure Blob Storage through the `azurerm` backend.

## Staging State Location

- resource group: `rg-soccerintel-tfstate`
- storage account: `soccerinteltfstate`
- container: `tfstate`
- key: `soccerintel/staging/platform-api.tfstate`

## Principles

- state storage is separate from application hosting resources
- state container is private
- state is shared between local operators and CI/CD
- locking and consistency are handled by Azure Blob Storage backend behavior

## Future Expansion

Later add:
- production state key
- additional state keys for Databricks infrastructure
- additional state keys for shared platform infrastructure

