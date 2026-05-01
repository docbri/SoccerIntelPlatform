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

echo "Restarting ${AZURE_WEBAPP_NAME}/${WEB_APP_SLOT}..."
az webapp restart \
  --resource-group "${AZURE_RESOURCE_GROUP}" \
  --name "${AZURE_WEBAPP_NAME}" \
  --slot "${WEB_APP_SLOT}"

echo "Platform.Api deployment complete."

