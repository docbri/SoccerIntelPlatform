# Azure Remote State Bootstrap

## Purpose

Describe the Azure storage resources required before OpenTofu can use remote state for shared environments.

## Required Azure Objects

- resource group for state storage
- storage account for OpenTofu state
- private blob container

## First Intended Staging Values

- resource group: `rg-soccerintel-tfstate`
- storage account: `soccerinteltfstate`
- container: `tfstate`

## Example State Key

- `soccerintel/staging/platform-api-v2.tfstate`

## Notes

OpenTofu remote state should be enabled before shared CI/CD planning and apply workflows are treated as authoritative.

State storage should be secured and treated as a control-plane asset.

