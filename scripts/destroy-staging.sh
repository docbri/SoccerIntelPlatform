#!/usr/bin/env bash
set -euo pipefail

echo "Destroying SoccerIntelPlatform staging infrastructure..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

DATABRICKS_CATALOG="${DATABRICKS_CATALOG:-soccerintel_staging}"
DATABRICKS_ADB_CATALOG_PREFIX="${DATABRICKS_ADB_CATALOG_PREFIX:-adb_soccerintel_staging_}"
DATABRICKS_EXTERNAL_LOCATION="${DATABRICKS_EXTERNAL_LOCATION:-soccerintel-staging-storage}"
DATABRICKS_STORAGE_CREDENTIAL="${DATABRICKS_STORAGE_CREDENTIAL:-soccerintel-staging-credential}"

DATABRICKS_WORKSPACE_URL=""
DATABRICKS_HOST_VALUE=""
DATABRICKS_PROFILE=""

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Resolving Databricks workspace output..."

if DATABRICKS_WORKSPACE_URL="$(tofu output -raw databricks_workspace_url 2>/dev/null)"; then
  DATABRICKS_HOST_VALUE="https://${DATABRICKS_WORKSPACE_URL}"
  DATABRICKS_PROFILE="$(echo "${DATABRICKS_HOST_VALUE}" | sed 's|https://||' | cut -d'.' -f1)"

  echo "Databricks workspace host resolved from OpenTofu output: ${DATABRICKS_HOST_VALUE}"
  echo "Databricks profile for this workspace: ${DATABRICKS_PROFILE}"

  echo "Discovering project Databricks catalogs..."

  CATALOGS="$(
    DATABRICKS_HOST="${DATABRICKS_HOST_VALUE}" databricks catalogs list 2>/dev/null \
      | awk 'NR>1 {print $1}'
  )"

  for catalog in ${CATALOGS}; do
    if [[ "${catalog}" == "${DATABRICKS_CATALOG}" || "${catalog}" == "${DATABRICKS_ADB_CATALOG_PREFIX}"* ]]; then
      echo "Deleting Databricks catalog: ${catalog}"
      DATABRICKS_HOST="${DATABRICKS_HOST_VALUE}" databricks catalogs delete "${catalog}" --force || true
    fi
  done

  echo "Deleting Databricks external location: ${DATABRICKS_EXTERNAL_LOCATION}"
  DATABRICKS_HOST="${DATABRICKS_HOST_VALUE}" databricks external-locations delete "${DATABRICKS_EXTERNAL_LOCATION}" --force || true

  echo "Deleting Databricks storage credential: ${DATABRICKS_STORAGE_CREDENTIAL}"
  DATABRICKS_HOST="${DATABRICKS_HOST_VALUE}" databricks storage-credentials delete "${DATABRICKS_STORAGE_CREDENTIAL}" --force || true
else
  echo "No Databricks workspace output found. Skipping Databricks Unity Catalog cleanup."
fi

echo "Running OpenTofu destroy..."

if [[ -n "${DATABRICKS_HOST_VALUE}" ]]; then
  DATABRICKS_HOST="${DATABRICKS_HOST_VALUE}" tofu destroy -auto-approve
else
  tofu destroy -auto-approve
fi

if [[ -n "${DATABRICKS_PROFILE}" ]]; then
  echo "Cleaning Databricks CLI profile for destroyed workspace: ${DATABRICKS_PROFILE}"
  databricks auth logout -p "${DATABRICKS_PROFILE}" --delete --auto-approve || true
else
  echo "No Databricks profile resolved for this destroy run. Skipping profile cleanup."
fi

echo "Staging infrastructure destroy complete."
