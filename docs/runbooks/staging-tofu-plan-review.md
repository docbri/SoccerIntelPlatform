# Staging OpenTofu Plan Review

## Purpose

Describe how the Staging infrastructure plan is generated and reviewed in CI.

## Current Workflow Behavior

On push to `main` for infrastructure changes, or on manual workflow dispatch:

- validate the Staging environment root
- initialize against Azure Blob remote state
- run the staging infrastructure plan through `scripts/up-staging.sh plan`
- upload both:
  - `staging.tfplan`
  - `staging-plan.txt`

## Artifact Meaning

### `staging.tfplan`

Machine-readable OpenTofu plan output.

### `staging-plan.txt`

Human-readable plan summary for review.

## Script Boundary

The workflow remains a thin runner.

Staging infrastructure plan behavior lives in:

```text
scripts/up-staging.sh
