#!/usr/bin/env bash
set -euo pipefail

echo "Destroying SoccerIntelPlatform staging infrastructure..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Checking Databricks workspace output..."

if DATABRICKS_WORKSPACE_URL="$(tofu output -raw databricks_workspace_url 2>/dev/null)"; then
  export DATABRICKS_HOST="https://${DATABRICKS_WORKSPACE_URL}"
  echo "Databricks workspace host resolved from OpenTofu output: ${DATABRICKS_HOST}"
  echo "No Databricks CLI login, profile switch, profile deletion, or Unity Catalog object deletion will be performed by this script."
else
  echo "No Databricks workspace output found. Continuing with OpenTofu destroy."
fi

echo "Running OpenTofu destroy..."
tofu destroy -auto-approve

echo "Staging infrastructure destroy complete."
