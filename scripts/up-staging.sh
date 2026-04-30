#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-apply}"

case "${MODE}" in
  plan|apply)
    ;;
  *)
    echo "Usage: $0 [plan|apply]"
    echo
    echo "Modes:"
    echo "  plan   Initialize and generate a staging OpenTofu plan only."
    echo "  apply  Initialize, apply staging infrastructure, then verify Databricks."
    exit 1
    ;;
esac

echo "Bringing up SoccerIntelPlatform staging infrastructure..."
echo "Mode: ${MODE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"

SSH_DIR="${HOME}/.ssh"
SSH_PRIVATE_KEY="${SSH_DIR}/id_rsa"
SSH_PUBLIC_KEY="${SSH_PRIVATE_KEY}.pub"

ensure_ssh_key() {
  echo "Ensuring SSH key exists for Redpanda VM planning/apply..."

  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"

  if [[ ! -f "${SSH_PRIVATE_KEY}" || ! -f "${SSH_PUBLIC_KEY}" ]]; then
    echo "SSH key pair not found. Creating one at ${SSH_PRIVATE_KEY}..."
    ssh-keygen \
      -t rsa \
      -b 4096 \
      -f "${SSH_PRIVATE_KEY}" \
      -N "" \
      -C "soccerintel-staging"
  else
    echo "SSH key pair already exists."
  fi

  chmod 600 "${SSH_PRIVATE_KEY}"
  chmod 644 "${SSH_PUBLIC_KEY}"

  echo "SSH public key available at: ${SSH_PUBLIC_KEY}"
}

echo "Repo root: ${REPO_ROOT}"
echo "Staging OpenTofu directory: ${STAGING_DIR}"

ensure_ssh_key

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

if [[ "${MODE}" == "plan" ]]; then
  echo "Planning infrastructure..."
  tofu plan -out=staging.tfplan

  echo "Rendering plan..."
  tofu show -no-color staging.tfplan > staging-plan.txt

  echo "Staging infrastructure plan complete."
  exit 0
fi

echo "Applying infrastructure..."
tofu apply -auto-approve

echo "Resolving Databricks workspace URL..."
DATABRICKS_HOST="https://$(tofu output -raw databricks_workspace_url)"

echo "Authenticating Databricks CLI..."

# Login creates/updates profile.
databricks auth login --host "${DATABRICKS_HOST}"

# Derive profile name exactly how CLI does.
DATABRICKS_PROFILE="$(echo "${DATABRICKS_HOST}" | sed 's|https://||' | cut -d'.' -f1)"

echo "Using Databricks profile: ${DATABRICKS_PROFILE}"

echo "Setting this profile as DEFAULT..."
databricks auth switch -p "${DATABRICKS_PROFILE}"

echo "Verifying Unity Catalog..."

databricks catalogs list -p "${DATABRICKS_PROFILE}"
databricks schemas list soccerintel_staging -p "${DATABRICKS_PROFILE}"

echo "Staging infrastructure is up and verified."
