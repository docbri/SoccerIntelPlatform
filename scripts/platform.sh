#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
DATABRICKS_DIR="${ROOT_DIR}/databricks"
STAGING_DIR="${ROOT_DIR}/infra/terraform/env/staging"
STAGING_TFVARS="${STAGING_DIR}/terraform.tfvars"

TARGET="${DATABRICKS_TARGET:-staging}"
BUNDLE_JOB="${DATABRICKS_BUNDLE_JOB:-medallion-slice}"

DATABRICKS_CATALOG="${DATABRICKS_CATALOG:-soccerintel_staging}"
DATABRICKS_BRONZE_SCHEMA="${DATABRICKS_BRONZE_SCHEMA:-bronze}"
DATABRICKS_SILVER_SCHEMA="${DATABRICKS_SILVER_SCHEMA:-silver}"
DATABRICKS_GOLD_SCHEMA="${DATABRICKS_GOLD_SCHEMA:-gold}"

BRONZE_RAW_INGESTION_EVENTS_TABLE="${BRONZE_RAW_INGESTION_EVENTS_TABLE:-raw_ingestion_events}"
SILVER_LEAGUE_STATUS_EVENTS_TABLE="${SILVER_LEAGUE_STATUS_EVENTS_TABLE:-league_status_events}"
GOLD_CURRENT_LEAGUE_STATUS_TABLE="${GOLD_CURRENT_LEAGUE_STATUS_TABLE:-current_league_status}"

WEB_APP_SLOT="${WEB_APP_SLOT:-staging}"
REDPANDA_VM_NAME="${REDPANDA_VM_NAME:-vm-redpanda-staging}"
REDPANDA_PUBLIC_IP_NAME="${REDPANDA_PUBLIC_IP_NAME:-pip-redpanda}"

usage() {
  cat <<EOF_USAGE
Usage:
  ./scripts/platform.sh plan
  ./scripts/platform.sh up
  ./scripts/platform.sh down
  ./scripts/platform.sh verify
  ./scripts/platform.sh resume
  ./scripts/platform.sh reset

Environment overrides:
  DATABRICKS_TARGET                         Default: staging
  DATABRICKS_BUNDLE_JOB                     Default: medallion-slice
  DATABRICKS_CATALOG                        Default: soccerintel_staging
  DATABRICKS_BRONZE_SCHEMA                  Default: bronze
  DATABRICKS_SILVER_SCHEMA                  Default: silver
  DATABRICKS_GOLD_SCHEMA                    Default: gold
  BRONZE_RAW_INGESTION_EVENTS_TABLE         Default: raw_ingestion_events
  SILVER_LEAGUE_STATUS_EVENTS_TABLE         Default: league_status_events
  GOLD_CURRENT_LEAGUE_STATUS_TABLE          Default: current_league_status
  AZURE_RESOURCE_GROUP                      Default: terraform.tfvars resource_group_name
  AZURE_WEBAPP_NAME                         Default: terraform.tfvars web_app_name
  WEB_APP_SLOT                              Default: staging
  REDPANDA_VM_NAME                          Default: vm-redpanda-staging
  REDPANDA_PUBLIC_IP_NAME                   Default: pip-redpanda
EOF_USAGE
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_file() {
  local file_path="$1"

  if [[ ! -f "${file_path}" ]]; then
    echo "ERROR: Required file not found: ${file_path}" >&2
    exit 1
  fi
}

require_dir() {
  local dir_path="$1"

  if [[ ! -d "${dir_path}" ]]; then
    echo "ERROR: Required directory not found: ${dir_path}" >&2
    exit 1
  fi
}

read_tofu_var() {
  local var_name="$1"

  require_file "${STAGING_TFVARS}"

  awk -F'=' -v key="${var_name}" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = $2
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "${STAGING_TFVARS}"
}

azure_resource_group() {
  if [[ -n "${AZURE_RESOURCE_GROUP:-}" ]]; then
    printf '%s\n' "${AZURE_RESOURCE_GROUP}"
    return
  fi

  read_tofu_var "resource_group_name"
}

azure_webapp_name() {
  if [[ -n "${AZURE_WEBAPP_NAME:-}" ]]; then
    printf '%s\n' "${AZURE_WEBAPP_NAME}"
    return
  fi

  read_tofu_var "web_app_name"
}

run_databricks_bundle_validate() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Validating Databricks bundle for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"
    run_with_current_databricks_profile databricks bundle validate -t "${TARGET}"
  )
}

run_databricks_bundle_deploy() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Deploying Databricks bundle for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"
    run_with_current_databricks_profile databricks bundle deploy -t "${TARGET}"
  )
}

run_databricks_bundle_run() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Running Databricks bundle job: ${BUNDLE_JOB}"

  (
    cd "${DATABRICKS_DIR}"

    if run_with_current_databricks_profile databricks bundle run -t "${TARGET}" "${BUNDLE_JOB}"; then
      return 0
    fi

    echo "Retrying Databricks bundle run with alternate CLI argument ordering..."

    run_with_current_databricks_profile databricks bundle run "${BUNDLE_JOB}" -t "${TARGET}"
  )
}

run_databricks_bundle_destroy() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Destroying Databricks bundle resources for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"

    if run_with_current_databricks_profile databricks bundle destroy -t "${TARGET}" --auto-approve; then
      return 0
    fi

    echo "WARNING: Databricks bundle destroy failed or is unsupported in this context." >&2
    echo "Continuing teardown so local/platform cleanup can proceed." >&2
  )
}

verify_azure_login() {
  require_command az

  echo "Verifying Azure CLI authentication..."
  az account show >/dev/null
}

verify_azure_resource_group() {
  local resource_group_name="$1"

  echo "Verifying Azure resource group: ${resource_group_name}"
  az group show \
    --name "${resource_group_name}" \
    --query name \
    --output tsv \
    >/dev/null
}

verify_azure_webapp() {
  local resource_group_name="$1"
  local webapp_name="$2"

  echo "Verifying Azure App Service: ${webapp_name}"
  az webapp show \
    --resource-group "${resource_group_name}" \
    --name "${webapp_name}" \
    --query name \
    --output tsv \
    >/dev/null
}

verify_azure_webapp_slot() {
  local resource_group_name="$1"
  local webapp_name="$2"
  local slot_name="$3"
  local resolved_slot_name
  local default_hostname

  echo "Verifying Azure App Service slot: ${webapp_name}/${slot_name}"

  resolved_slot_name="$(
    az webapp deployment slot list \
      --resource-group "${resource_group_name}" \
      --name "${webapp_name}" \
      --query "[?name=='${slot_name}'].name | [0]" \
      --output tsv
  )"

  if [[ "${resolved_slot_name}" != "${slot_name}" ]]; then
    echo "ERROR: Azure App Service slot not found: ${webapp_name}/${slot_name}" >&2
    exit 1
  fi

  default_hostname="$(
    az webapp deployment slot list \
      --resource-group "${resource_group_name}" \
      --name "${webapp_name}" \
      --query "[?name=='${slot_name}'].defaultHostName | [0]" \
      --output tsv
  )"

  if [[ -z "${default_hostname}" ]]; then
    echo "ERROR: Could not resolve default hostname for slot: ${webapp_name}/${slot_name}" >&2
    exit 1
  fi

  echo "Verifying Platform.Api health endpoint: https://${default_hostname}/health"

  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "https://${default_hostname}/health" \
    >/dev/null
}

verify_azure_vm() {
  local resource_group_name="$1"
  local vm_name="$2"

  echo "Verifying Azure VM: ${vm_name}"
  az vm show \
    --resource-group "${resource_group_name}" \
    --name "${vm_name}" \
    --query name \
    --output tsv \
    >/dev/null
}

verify_azure_public_ip() {
  local resource_group_name="$1"
  local public_ip_name="$2"

  echo "Verifying Azure public IP: ${public_ip_name}"
  az network public-ip show \
    --resource-group "${resource_group_name}" \
    --name "${public_ip_name}" \
    --query name \
    --output tsv \
    >/dev/null
}

verify_azure_platform_objects() {
  local resource_group_name
  local webapp_name

  resource_group_name="$(azure_resource_group)"
  webapp_name="$(azure_webapp_name)"

  if [[ -z "${resource_group_name}" ]]; then
    echo "ERROR: Could not resolve Azure resource group." >&2
    echo "Set AZURE_RESOURCE_GROUP or define resource_group_name in ${STAGING_TFVARS}." >&2
    exit 1
  fi

  if [[ -z "${webapp_name}" ]]; then
    echo "ERROR: Could not resolve Azure App Service name." >&2
    echo "Set AZURE_WEBAPP_NAME or define web_app_name in ${STAGING_TFVARS}." >&2
    exit 1
  fi

  verify_azure_login
  verify_azure_resource_group "${resource_group_name}"
  verify_azure_webapp "${resource_group_name}" "${webapp_name}"
  verify_azure_webapp_slot "${resource_group_name}" "${webapp_name}" "${WEB_APP_SLOT}"
  verify_azure_vm "${resource_group_name}" "${REDPANDA_VM_NAME}"
  verify_azure_public_ip "${resource_group_name}" "${REDPANDA_PUBLIC_IP_NAME}"
}

current_databricks_host() {
  local workspace_url

  workspace_url="$(cd "${STAGING_DIR}" && tofu output -raw databricks_workspace_url)"
  printf 'https://%s\n' "${workspace_url}"
}

databricks_profile_for_host() {
  local host="$1"

  echo "${host}" | sed 's|https://||' | cut -d'.' -f1
}

run_with_current_databricks_profile() {
  local host
  local profile

  host="$(current_databricks_host)"
  profile="$(databricks_profile_for_host "${host}")"

  echo "Using Databricks host for bundle command: ${host}"
  echo "Using Databricks profile for bundle command: ${profile}"

  env \
    -u DATABRICKS_HOST \
    -u DATABRICKS_AZURE_TENANT_ID \
    -u DATABRICKS_CLIENT_ID \
    -u DATABRICKS_CLIENT_SECRET \
    DATABRICKS_CONFIG_PROFILE="${profile}" \
    "$@"
}

verify_databricks_catalog() {
   local catalog_name="$1"
 
   echo "Verifying Databricks catalog: ${catalog_name}"
   run_with_current_databricks_profile databricks catalogs get "${catalog_name}" >/dev/null
 }
 
 verify_databricks_schema() {
   local catalog_name="$1"
   local schema_name="$2"
   local full_schema_name="${catalog_name}.${schema_name}"
 
   echo "Verifying Databricks schema: ${full_schema_name}"
   run_with_current_databricks_profile databricks schemas get "${full_schema_name}" >/dev/null
 }
 
 verify_databricks_table() {
   local catalog_name="$1"
   local schema_name="$2"
   local table_name="$3"
   local full_table_name="${catalog_name}.${schema_name}.${table_name}"
 
   echo "Verifying Databricks table: ${full_table_name}"
   run_with_current_databricks_profile databricks tables get "${full_table_name}" >/dev/null
 }

verify_databricks_unity_catalog_objects() {
  require_command databricks

  verify_databricks_catalog "${DATABRICKS_CATALOG}"

  verify_databricks_schema "${DATABRICKS_CATALOG}" "${DATABRICKS_BRONZE_SCHEMA}"
  verify_databricks_schema "${DATABRICKS_CATALOG}" "${DATABRICKS_SILVER_SCHEMA}"
  verify_databricks_schema "${DATABRICKS_CATALOG}" "${DATABRICKS_GOLD_SCHEMA}"

  verify_databricks_table \
    "${DATABRICKS_CATALOG}" \
    "${DATABRICKS_BRONZE_SCHEMA}" \
    "${BRONZE_RAW_INGESTION_EVENTS_TABLE}"

  verify_databricks_table \
    "${DATABRICKS_CATALOG}" \
    "${DATABRICKS_SILVER_SCHEMA}" \
    "${SILVER_LEAGUE_STATUS_EVENTS_TABLE}"

  verify_databricks_table \
    "${DATABRICKS_CATALOG}" \
    "${DATABRICKS_GOLD_SCHEMA}" \
    "${GOLD_CURRENT_LEAGUE_STATUS_TABLE}"
}

plan_platform() {
  require_file "${SCRIPTS_DIR}/up-staging.sh"

  echo "Planning staging infrastructure..."
  "${SCRIPTS_DIR}/up-staging.sh" plan
}

up_platform() {
  require_file "${SCRIPTS_DIR}/up-staging.sh"
  require_file "${SCRIPTS_DIR}/up-redpanda.sh"
  require_file "${SCRIPTS_DIR}/deploy-platform-api.sh"

  echo "Applying staging infrastructure..."
  "${SCRIPTS_DIR}/up-staging.sh" apply
  
  echo "Deploying Platform.Api..."
  "${SCRIPTS_DIR}/deploy-platform-api.sh"

  echo "Bringing up Redpanda..."
  "${SCRIPTS_DIR}/up-redpanda.sh"

  run_databricks_bundle_validate
  run_databricks_bundle_deploy
  run_databricks_bundle_run

  verify_platform
}

down_platform() {
  require_file "${SCRIPTS_DIR}/destroy-redpanda.sh"
  require_file "${SCRIPTS_DIR}/destroy-staging.sh"

  run_databricks_bundle_destroy || true

  echo "Destroying Redpanda..."
  "${SCRIPTS_DIR}/destroy-redpanda.sh"

  echo "Destroying staging infrastructure..."
  "${SCRIPTS_DIR}/destroy-staging.sh"
}

reset_platform() {
  local expected_confirmation="destroy-staging-data"
  local table

  if [[ "${CONFIRM_DESTRUCTIVE_RESET:-}" != "${expected_confirmation}" ]]; then
    echo "ERROR: Destructive staging reset requires explicit confirmation." >&2
    echo "This will delete known Databricks managed medallion tables before running ordinary teardown." >&2
    echo "Required confirmation:" >&2
    echo "  CONFIRM_DESTRUCTIVE_RESET=${expected_confirmation} ./scripts/platform.sh reset" >&2
    exit 1
  fi

  require_command databricks

  echo "Destructive staging reset confirmed."
  echo "Resolving Databricks workspace host from OpenTofu output..."

  export DATABRICKS_HOST="https://$(cd "${STAGING_DIR}" && tofu output -raw databricks_workspace_url)"

  echo "Using Databricks host from OpenTofu output: ${DATABRICKS_HOST}"
  echo "Deleting known Databricks managed medallion tables..."

  for table in \
    "${DATABRICKS_CATALOG}.${DATABRICKS_GOLD_SCHEMA}.${GOLD_CURRENT_LEAGUE_STATUS_TABLE}" \
    "${DATABRICKS_CATALOG}.${DATABRICKS_SILVER_SCHEMA}.${SILVER_LEAGUE_STATUS_EVENTS_TABLE}" \
    "${DATABRICKS_CATALOG}.${DATABRICKS_BRONZE_SCHEMA}.${BRONZE_RAW_INGESTION_EVENTS_TABLE}"
  do
    if databricks tables get "${table}" >/dev/null 2>&1; then
      echo "Deleting Databricks table: ${table}"
      databricks tables delete "${table}"
    else
      echo "Databricks table not found; skipping: ${table}"
    fi
  done

  echo "Known Databricks medallion tables deleted or absent."
  echo "Running ordinary platform teardown..."
  down_platform
}

verify_platform() {
  echo "Verifying platform..."

  verify_azure_platform_objects

  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  run_databricks_bundle_validate
  verify_databricks_unity_catalog_objects

  echo "Platform verification completed."
}

resume_platform() {
  echo "Resuming platform runtime..."

  run_databricks_bundle_validate
  run_databricks_bundle_deploy
  run_databricks_bundle_run

  verify_platform
}

main() {
  local action="${1:-}"

  case "${action}" in
    plan)
      plan_platform
      ;;
    up)
      up_platform
      ;;
    down)
      down_platform
      ;;
    reset)
      reset_platform
      ;;
    verify)
      verify_platform
      ;;
    resume)
      resume_platform
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "ERROR: Unknown action: ${action}" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
