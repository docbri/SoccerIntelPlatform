# Staging OpenTofu Plan Review

## Purpose

Describe how the Staging infrastructure plan is generated and reviewed in CI.

## Current Workflow Behavior

On push to `main` for infrastructure changes:
- validate the Staging environment root
- initialize against Azure Blob remote state
- run `tofu plan`
- upload both:
  - `staging.tfplan`
  - `staging-plan.txt`

## Artifact Meaning

### `staging.tfplan`
Machine-readable OpenTofu plan output.

### `staging-plan.txt`
Human-readable plan summary for review.

## Review Principle

Infrastructure changes should be reviewed as a plan before apply is introduced.

## Backend Note

The workflow now uses the real Azure Blob remote state backend for the Staging environment.
