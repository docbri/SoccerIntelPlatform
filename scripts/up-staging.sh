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

DATABRICKS_CATALOG="${DATABRICKS_CATALOG:-soccerintel_staging}"
DATABRICKS_BRONZE_SCHEMA="${DATABRICKS_BRONZE_SCHEMA:-bronze}"
DATABRICKS_SILVER_SCHEMA="${DATABRICKS_SILVER_SCHEMA:-silver}"
DATABRICKS_GOLD_SCHEMA="${DATABRICKS_GOLD_SCHEMA:-gold}"

# CI supplies AZURE_CLIENT_ID through the GitHub staging environment.
# Locally, this may be unset. In that case, apply still verifies Databricks
# but skips grant mutation instead of asking the user to paste IDs.
DATABRICKS_GRANT_PRINCIPAL="${DATABRICKS_GRANT_PRINCIPAL:-${AZURE_CLIENT_ID:-}}"

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

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${command_name}" >&2
    exit 1
  fi
}

databricks_grants_update() {
  local securable_type="$1"
  local full_name="$2"
  local principal="$3"
  shift 3

  local privileges_json
  local privilege
  local separator=""

  privileges_json="["
  for privilege in "$@"; do
    privileges_json="${privileges_json}${separator}\"${privilege}\""
    separator=", "
  done
  privileges_json="${privileges_json}]"

  echo "Granting ${privileges_json} on ${securable_type} ${full_name} to ${principal}"

  databricks grants update "${securable_type}" "${full_name}" \
    --json "{\"changes\":[{\"add\":${privileges_json},\"principal\":\"${principal}\"}]}" \
    >/dev/null
}

apply_databricks_ci_grants() {
  if [[ -z "${DATABRICKS_GRANT_PRINCIPAL}" ]]; then
    echo "WARNING: DATABRICKS_GRANT_PRINCIPAL/AZURE_CLIENT_ID is not set."
    echo "Skipping Databricks CI grants for local apply."
    echo "CI should provide AZURE_CLIENT_ID through the GitHub staging environment."
    return
  fi

  echo "Applying Databricks Unity Catalog grants for principal: ${DATABRICKS_GRANT_PRINCIPAL}"

  databricks_grants_update \
    catalog \
    "${DATABRICKS_CATALOG}" \
    "${DATABRICKS_GRANT_PRINCIPAL}" \
    USE_CATALOG

  databricks_grants_update \
    schema \
    "${DATABRICKS_CATALOG}.${DATABRICKS_BRONZE_SCHEMA}" \
    "${DATABRICKS_GRANT_PRINCIPAL}" \
    USE_SCHEMA

  databricks_grants_update \
    schema \
    "${DATABRICKS_CATALOG}.${DATABRICKS_SILVER_SCHEMA}" \
    "${DATABRICKS_GRANT_PRINCIPAL}" \
    USE_SCHEMA

  databricks_grants_update \
    schema \
    "${DATABRICKS_CATALOG}.${DATABRICKS_GOLD_SCHEMA}" \
    "${DATABRICKS_GRANT_PRINCIPAL}" \
    USE_SCHEMA

  echo "Databricks Unity Catalog grants applied."
}

verify_databricks_unity_catalog() {
  echo "Verifying Unity Catalog..."

  databricks catalogs get "${DATABRICKS_CATALOG}" >/dev/null
  databricks schemas get "${DATABRICKS_CATALOG}.${DATABRICKS_BRONZE_SCHEMA}" >/dev/null
  databricks schemas get "${DATABRICKS_CATALOG}.${DATABRICKS_SILVER_SCHEMA}" >/dev/null
  databricks schemas get "${DATABRICKS_CATALOG}.${DATABRICKS_GOLD_SCHEMA}" >/dev/null
}

echo "Repo root: ${REPO_ROOT}"
echo "Staging OpenTofu directory: ${STAGING_DIR}"

cd "${STAGING_DIR}"

echo "Initializing..."
tofu init -reconfigure

if [[ "${MODE}" == "plan" ]]; then
  ensure_ssh_public_key_for_plan

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
export DATABRICKS_HOST="https://$(tofu output -raw databricks_workspace_url)"
echo "Using Databricks host from OpenTofu output: ${DATABRICKS_HOST}"

echo "Verifying Databricks CLI authentication..."
databricks catalogs get "${DATABRICKS_CATALOG}" >/dev/null

apply_databricks_ci_grants
verify_databricks_unity_catalog

echo "Staging infrastructure is up and verified."
