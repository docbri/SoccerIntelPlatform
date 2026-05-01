# Staging OpenTofu Plan Review

## Purpose

Describe how the staging infrastructure plan is generated and reviewed locally and in CI.

## Current Workflow Behavior

The infrastructure workflow is:

    .github/workflows/terraform-ci.yml

On push to `main` for infrastructure/script/workflow changes, or on manual workflow dispatch, `infra-ci`:

- validates the staging OpenTofu root
- initializes against Azure Blob remote state
- runs the staging infrastructure plan through the public platform lifecycle script
- uploads both plan artifacts:
  - `staging.tfplan`
  - `staging-plan.txt`

The plan command used by CI is:

    ./scripts/platform.sh plan

## Local Plan Review

Run from the repository root:

    ./scripts/platform.sh plan

This produces:

- `infra/terraform/env/staging/staging.tfplan`
- `infra/terraform/env/staging/staging-plan.txt`

Review the human-readable plan:

    less infra/terraform/env/staging/staging-plan.txt

## Artifact Meaning

### `staging.tfplan`

Machine-readable OpenTofu plan output.

This file is useful for exact OpenTofu apply/review workflows, but should not be hand-edited.

### `staging-plan.txt`

Human-readable OpenTofu plan output.

This is the primary review artifact for understanding proposed infrastructure changes.

## Script Boundary

GitHub Actions should remain a thin runner.

The workflow should not contain project-specific infrastructure behavior beyond:

- checkout
- tool setup
- Azure OIDC login
- OpenTofu validation
- calling the platform lifecycle script
- uploading artifacts

The staging infrastructure plan behavior lives behind:

    ./scripts/platform.sh plan

`platform.sh plan` currently delegates to the staging OpenTofu planning implementation.

## Locking Note

The OpenTofu backend uses remote state locking.

A push to `main` can trigger `infra-ci`, and `infra-ci` may hold the OpenTofu state lock while the plan job runs.

If a local plan fails because the remote state lock is held, wait for the GitHub Actions workflow to complete, then rerun:

    ./scripts/platform.sh plan

Do not force-unlock unless the lock is known to be stale.

## Non-Mutation Rule

The plan path must remain non-mutating.

It should not:

- apply infrastructure
- create or destroy Redpanda resources
- deploy Databricks bundle resources
- run Databricks jobs
- mutate Databricks grants
- create or switch Databricks CLI profiles

If any of those behaviors are needed, use a different lifecycle command such as:

    ./scripts/platform.sh up
    ./scripts/platform.sh resume
    ./scripts/platform.sh down

## Expected Successful Result

A successful no-change plan ends with:

    No changes. Your infrastructure matches the configuration.

and then:

    Staging infrastructure plan complete.
