#!/usr/bin/env bash
set -euo pipefail

echo "Deploying Platform.Api to Azure App Service staging slot..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAGING_DIR="${REPO_ROOT}/infra/terraform/env/staging"
PUBLISH_DIR="${REPO_ROOT}/publish/api"
ZIP_PATH="${REPO_ROOT}/publish/platform-api.zip"

AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
AZURE_WEBAPP_NAME="${AZURE_WEBAPP_NAME:-}"
WEB_APP_SLOT="${WEB_APP_SLOT:-staging}"

read_tofu_var() {
  local var_name="$1"

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
  ' "${STAGING_DIR}/terraform.tfvars"
}

read_tofu_output() {
  local output_name="$1"

  (
    cd "${STAGING_DIR}"
    tofu output -raw "${output_name}"
  )
}

deploy_zip_package() {
  local attempt
  local max_attempts=12
  local sleep_seconds=10

  echo "Deploying package to ${AZURE_WEBAPP_NAME}/${WEB_APP_SLOT}..."

  for attempt in $(seq 1 "${max_attempts}"); do
    echo "Zip deployment attempt ${attempt}/${max_attempts}..."

    if az webapp deployment source config-zip \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AZURE_WEBAPP_NAME}" \
      --slot "${WEB_APP_SLOT}" \
      --src "${ZIP_PATH}" \
      >/dev/null; then
      echo "Zip deployment succeeded."
      return 0
    fi

    echo "Zip deployment endpoint not ready yet. Waiting ${sleep_seconds}s before retry..."
    sleep "${sleep_seconds}"
  done

  echo "ERROR: Zip deployment failed after ${max_attempts} attempts." >&2
  exit 1
}

configure_app_settings() {
  local databricks_workspace_url
  local databricks_sql_warehouse_id
  local databricks_catalog_name
  local databricks_gold_schema_name
  local settings

  databricks_workspace_url="https://$(read_tofu_output "databricks_workspace_url")"
  databricks_sql_warehouse_id="$(read_tofu_output "databricks_sql_warehouse_id")"
  databricks_catalog_name="$(read_tofu_output "databricks_catalog_name")"
  databricks_gold_schema_name="$(read_tofu_output "databricks_gold_schema_name")"

  echo "Configuring Platform.Api staging slot settings..."
  echo "Databricks workspace URL: ${databricks_workspace_url}"
  echo "Databricks SQL warehouse ID: ${databricks_sql_warehouse_id}"
  echo "Databricks catalog: ${databricks_catalog_name}"
  echo "Databricks schema: ${databricks_gold_schema_name}"

  settings=(
    "ASPNETCORE_ENVIRONMENT=Staging"
    "Readiness__DatabricksTimeoutSeconds=60"
    "DatabricksSql__WorkspaceUrl=${databricks_workspace_url}"
    "DatabricksSql__WarehouseId=${databricks_sql_warehouse_id}"
    "DatabricksSql__Catalog=${databricks_catalog_name}"
    "DatabricksSql__Schema=${databricks_gold_schema_name}"
    "DatabricksSql__CurrentLeagueStatusObjectName=current_league_status"
    "DatabricksSql__AuthenticationType=Token"
  )

wait_for_readiness() {
  local default_hostname
  local ready_url
  local attempt
  local max_attempts=18
  local sleep_seconds=10
  local status_code

  echo "Resolving staging slot hostname..."

  default_hostname="$(
    az webapp deployment slot list \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AZURE_WEBAPP_NAME}" \
      --query "[?name=='${WEB_APP_SLOT}'].defaultHostName | [0]" \
      --output tsv
  )"

  if [[ -z "${default_hostname}" ]]; then
    echo "ERROR: Could not resolve default hostname for ${AZURE_WEBAPP_NAME}/${WEB_APP_SLOT}." >&2
    exit 1
  fi

  ready_url="https://${default_hostname}/ready"

  echo "Waiting for Platform.Api readiness: ${ready_url}"

  for attempt in $(seq 1 "${max_attempts}"); do
    status_code="$(
      curl -sS \
        --max-time 75 \
        --output /dev/null \
        --write-out "%{http_code}" \
        "${ready_url}" || true
    )"

    if [[ "${status_code}" == "200" ]]; then
      echo "Platform.Api readiness endpoint is ready."
      return 0
    fi

    echo "Platform.Api readiness not ready yet. HTTP ${status_code}. Retry ${attempt}/${max_attempts}..."
    sleep "${sleep_seconds}"
  done

  echo "ERROR: Platform.Api readiness endpoint did not become ready: ${ready_url}" >&2
  exit 1
}

wait_for_gold_endpoint() {
  local default_hostname
  local gold_url
  local attempt
  local max_attempts=12
  local sleep_seconds=10
  local status_code

  echo "Resolving staging slot hostname..."

  default_hostname="$(
    az webapp deployment slot list \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AZURE_WEBAPP_NAME}" \
      --query "[?name=='${WEB_APP_SLOT}'].defaultHostName | [0]" \
      --output tsv
  )"

  if [[ -z "${default_hostname}" ]]; then
    echo "ERROR: Could not resolve default hostname for ${AZURE_WEBAPP_NAME}/${WEB_APP_SLOT}." >&2
    exit 1
  fi

  gold_url="https://${default_hostname}/league-status/current?leagueId=135&season=2025"

  echo "Waiting for Platform.Api Gold endpoint: ${gold_url}"

  for attempt in $(seq 1 "${max_attempts}"); do
    status_code="$(
      curl -sS \
        --max-time 75 \
        --output /dev/null \
        --write-out "%{http_code}" \
        "${gold_url}" || true
    )"

    if [[ "${status_code}" == "200" ]]; then
      echo "Platform.Api Gold endpoint is ready."
      return 0
    fi

    echo "Platform.Api Gold endpoint not ready yet. HTTP ${status_code}. Retry ${attempt}/${max_attempts}..."
    sleep "${sleep_seconds}"
  done

  echo "ERROR: Platform.Api Gold endpoint did not become ready: ${gold_url}" >&2
  exit 1
}

  if [[ -n "${DATABRICKS_SQL_ACCESS_TOKEN:-}" ]]; then
    echo "Databricks SQL access token: updating from environment"
    settings+=("DatabricksSql__AccessToken=${DATABRICKS_SQL_ACCESS_TOKEN}")
  else
    echo "Databricks SQL access token: preserving existing App Service setting"
  fi

  az webapp config appsettings set \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${AZURE_WEBAPP_NAME}" \
    --slot "${WEB_APP_SLOT}" \
    --settings "${settings[@]}" \
    >/dev/null
}

if [[ -z "${AZURE_RESOURCE_GROUP}" ]]; then
  AZURE_RESOURCE_GROUP="$(read_tofu_var "resource_group_name")"
fi

if [[ -z "${AZURE_WEBAPP_NAME}" ]]; then
  AZURE_WEBAPP_NAME="$(read_tofu_var "web_app_name")"
fi

if [[ -z "${AZURE_RESOURCE_GROUP}" ]]; then
  echo "ERROR: Could not resolve Azure resource group." >&2
  exit 1
fi

if [[ -z "${AZURE_WEBAPP_NAME}" ]]; then
  echo "ERROR: Could not resolve Azure Web App name." >&2
  exit 1
fi

rm -rf "${PUBLISH_DIR}" "${ZIP_PATH}"
mkdir -p "${PUBLISH_DIR}"

echo "Publishing Platform.Api..."
dotnet publish "${REPO_ROOT}/src/Platform.Api/Platform.Api.csproj" \
  -c Release \
  -o "${PUBLISH_DIR}"

echo "Creating deployment package..."
(
  cd "${PUBLISH_DIR}"
  zip -qr "${ZIP_PATH}" .
)

deploy_zip_package
configure_app_settings

echo "Restarting ${AZURE_WEBAPP_NAME}/${WEB_APP_SLOT}..."
az webapp restart \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AZURE_WEBAPP_NAME}" \
  --slot "${WEB_APP_SLOT}"

wait_for_readiness
wait_for_gold_endpoint

echo "Platform.Api deployment complete."
