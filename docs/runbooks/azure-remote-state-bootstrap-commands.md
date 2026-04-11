# Azure Remote State Bootstrap Commands

## Purpose

Create the Azure resources required for OpenTofu remote state before enabling the shared backend for the Staging environment.

## Intended First Values

- resource group: `rg-soccerintel-tfstate`
- storage account: `soccerinteltfstate`
- container: `tfstate`
- region: `centralus`

## Azure CLI Commands

### Create resource group
```bash
az group create \
  --name rg-soccerintel-tfstate \
  --location centralus

