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

REDPANDA_VM_STATE_ADDRESS="module.redpanda_vm.azurerm_linux_virtual_machine.this"

ensure_ssh_dir() {
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
}

redpanda_public_key_from_state() {
  tofu state show -no-color "${REDPANDA_VM_STATE_ADDRESS}" 2>/dev/null \
    | awk -F' = ' '
        $1 ~ /^[[:space:]]*public_key$/ {
          gsub(/^"/, "", $2)
          gsub(/"$/, "", $2)
          print $2
          exit
        }
      '
}

ensure_ssh_public_key_for_plan() {
  echo "Ensuring SSH public key exists for Redpanda VM planning..."

  ensure_ssh_dir

  local state_public_key
  state_public_key="$(redpanda_public_key_from_state || true)"

  if [[ -n "${state_public_key}" ]]; then
    echo "Using Redpanda SSH public key from OpenTofu state to avoid artificial VM replacement during plan."
    printf '%s\n' "${state_public_key}" > "${SSH_PUBLIC_KEY}"
    chmod 644 "${SSH_PUBLIC_KEY}"
    echo "SSH public key available at: ${SSH_PUBLIC_KEY}"
    return
  fi

  if [[ -f "${SSH_PUBLIC_KEY}" ]]; then
    echo "Using existing SSH public key at: ${SSH_PUBLIC_KEY}"
    chmod 644 "${SSH_PUBLIC_KEY}"
    return
  fi

  echo "No Redpanda VM key found in state and no local SSH public key exists."
  echo "Creating a temporary key pair for first-time planning at ${SSH_PRIVATE_KEY}..."

  ssh-keygen \
    -t rsa \
    -b 4096 \
    -f "${SSH_PRIVATE_KEY}" \
    -N "" \
    -C "soccerintel-staging"

  chmod 600 "${SSH_PRIVATE_KEY}"
  chmod 644 "${SSH_PUBLIC_KEY}"

  echo "SSH public key available at: ${SSH_PUBLIC_KEY}"
}

ensure_ssh_key_for_apply() {
  echo "Ensuring SSH key pair exists for Redpanda VM apply..."

  ensure_ssh_dir

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

configure_databricks_host_for_plan() {
  echo "Configuring Databricks host for plan diagnostics..."

  local workspace_url
  workspace_url="$(tofu output -raw databricks_workspace_url 2>/dev/null || true)"

  if [[ -z "${workspace_url}" ]]; then
    echo "No databricks_workspace_url output found. Skipping DATABRICKS_HOST export."
    return 0
  fi

  export DATABRICKS_HOST="https://${workspace_url}"
  export DATABRICKS_AUTH_TYPE="azure-cli"

  echo "DATABRICKS_HOST configured from OpenTofu output."
  echo "DATABRICKS_AUTH_TYPE configured as azure-cli."
}

diagnose_databricks_auth() {
  echo "Diagnosing Databricks authentication for OpenTofu..."

  if ! command -v databricks >/dev/null 2>&1; then
    echo "Databricks CLI is not installed; skipping Databricks identity diagnostic."
    return 0
  fi

  if [[ -z "${DATABRICKS_HOST:-}" ]]; then
    echo "DATABRICKS_HOST is not set in the shell."
    echo "OpenTofu provider host is configured from module.databricks_foundation.workspace_url."
  else
    echo "DATABRICKS_HOST is set."
  fi

  echo "Attempting Databricks current-user lookup..."
  databricks current-user me || true

  echo "Attempting Databricks storage credential lookup..."
  databricks storage-credentials get soccerintel-staging-credential || true
}

echo "Repo root: ${REPO_ROOT}"
echo "Staging OpenTofu directory: ${STAGING_DIR}"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

if [[ "${MODE}" == "plan" ]]; then
  ensure_ssh_public_key_for_plan

  configure_databricks_host_for_plan
  diagnose_databricks_auth

  echo "Planning infrastructure..."
  tofu plan -out=staging.tfplan

  echo "Rendering plan..."
  tofu show -no-color staging.tfplan > staging-plan.txt

  echo "Staging infrastructure plan complete."
  exit 0
fi

ensure_ssh_key_for_apply

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
