#!/usr/bin/env bash
set -euo pipefail

echo "Bringing up SoccerIntelPlatform staging infrastructure..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Applying infrastructure..."
tofu apply -auto-approve

echo "Resolving Databricks workspace URL..."
DATABRICKS_HOST="https://$(tofu output -raw databricks_workspace_url)"

echo "Authenticating Databricks CLI..."
databricks auth login --host "${DATABRICKS_HOST}"

# Derive profile name exactly how CLI does
DATABRICKS_PROFILE="$(echo "${DATABRICKS_HOST}" | sed 's|https://||' | cut -d'.' -f1)"

echo "Using Databricks profile: ${DATABRICKS_PROFILE}"

echo "Verifying Unity Catalog..."

databricks catalogs list -p "${DATABRICKS_PROFILE}"
databricks schemas list soccerintel_staging -p "${DATABRICKS_PROFILE}"

# --- REMOVED: databricks sql functional test (unsupported in this CLI) ---

echo "Staging infrastructure is up and verified."
