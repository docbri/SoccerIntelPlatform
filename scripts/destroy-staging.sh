#!/usr/bin/env bash
set -euo pipefail

echo "Destroying SoccerIntelPlatform staging infrastructure..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Running destroy..."
tofu destroy -auto-approve

echo "Cleaning Databricks CLI profiles..."

# Get all profile names (skip header)
PROFILES=$(databricks auth profiles 2>/dev/null | tail -n +2 | awk '{print $1}')

if [ -n "${PROFILES}" ]; then
  for profile in ${PROFILES}; do
    echo "Removing profile: ${profile}"
    yes | databricks auth logout -p "${profile}" --delete >/dev/null 2>&1 || true
  done
else
  echo "No Databricks profiles found."
fi

echo "Staging infrastructure destroyed and CLI cleaned."
