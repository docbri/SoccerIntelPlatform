#!/usr/bin/env bash
set -euo pipefail

echo "Destroying SoccerIntelPlatform staging infrastructure..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Resolving Databricks workspace (if present)..."

if DATABRICKS_WORKSPACE_URL="$(tofu output -raw databricks_workspace_url 2>/dev/null)"; then
  DATABRICKS_HOST="https://${DATABRICKS_WORKSPACE_URL}"
  DATABRICKS_PROFILE="$(echo "${DATABRICKS_HOST}" | sed 's|https://||' | cut -d'.' -f1)"

  echo "Authenticating Databricks CLI..."
  databricks auth login --host "${DATABRICKS_HOST}"

  echo "Discovering catalogs..."
  CATALOGS=$(databricks catalogs list -p "${DATABRICKS_PROFILE}" | awk 'NR>1 {print $1}')

  for catalog in ${CATALOGS}; do
    if [[ "$catalog" == adb_soccerintel_staging_* || "$catalog" == soccerintel_staging ]]; then
      echo "Deleting catalog: $catalog"
      databricks catalogs delete "$catalog" --force -p "${DATABRICKS_PROFILE}" || true
    fi
  done

  echo "Deleting external location..."
  databricks external-locations delete soccerintel-staging-storage --force -p "${DATABRICKS_PROFILE}" || true

  echo "Deleting storage credential..."
  databricks storage-credentials delete soccerintel-staging-credential --force -p "${DATABRICKS_PROFILE}" || true

else
  echo "No workspace found. Skipping UC cleanup."
fi

echo "Running Terraform destroy..."
tofu destroy -auto-approve

echo "Cleaning Databricks CLI profiles..."
PROFILES=$(databricks auth profiles 2>/dev/null | tail -n +2 | awk '{print $1}')

if [ -n "${PROFILES}" ]; then
  for profile in ${PROFILES}; do
    yes | databricks auth logout -p "${profile}" --delete >/dev/null 2>&1 || true
  done
fi

echo "Destroy complete."
