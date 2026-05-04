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
REDPANDA_PORT="${REDPANDA_PORT:-9092}"

WORKER_PROJECT="${WORKER_PROJECT:-${ROOT_DIR}/src/Platform.Worker/Platform.Worker.csproj}"
BRONZE_CONSUMER_PROJECT="${BRONZE_CONSUMER_PROJECT:-${ROOT_DIR}/src/Platform.BronzeConsumer/Platform.BronzeConsumer.csproj}"

RUNTIME_DIR="${ROOT_DIR}/.runtime"

INGEST_PID_FILE="${RUNTIME_DIR}/platform-worker.pid"
INGEST_STATE_FILE="${RUNTIME_DIR}/platform-ingest.env"
INGEST_LOG_FILE="${RUNTIME_DIR}/platform-worker.log"

BRONZE_CONSUMER_PID_FILE="${RUNTIME_DIR}/platform-bronze-consumer.pid"
BRONZE_CONSUMER_STATE_FILE="${RUNTIME_DIR}/platform-bronze-consumer.env"
BRONZE_CONSUMER_LOG_FILE="${RUNTIME_DIR}/platform-bronze-consumer.log"

BRONZE_CONSUMER_TOPIC_NAME="${BRONZE_CONSUMER_TOPIC_NAME:-soccer.raw.ingestion.dev}"
BRONZE_CONSUMER_GROUP_ID="${BRONZE_CONSUMER_GROUP_ID:-platform-bronze-consumer-dev}"
BRONZE_OUTPUT_PATH="${BRONZE_OUTPUT_PATH:-${ROOT_DIR}/localdata/bronze/raw_ingestion_events.jsonl}"
QUARANTINE_OUTPUT_PATH="${QUARANTINE_OUTPUT_PATH:-${ROOT_DIR}/localdata/quarantine/raw_ingestion_quarantine.jsonl}"

API_FOOTBALL_MAX_CALLS_PER_DAY="${API_FOOTBALL_MAX_CALLS_PER_DAY:-100}"
INGEST_DEFAULT_POLLS_PER_HOUR="${INGEST_DEFAULT_POLLS_PER_HOUR:-1}"

usage() {
  cat <<EOF_USAGE
Usage:
  ./scripts/platform.sh plan
  ./scripts/platform.sh up
  ./scripts/platform.sh down
  ./scripts/platform.sh verify
  ./scripts/platform.sh resume
  ./scripts/platform.sh reset

  ./scripts/platform.sh ingest once [--max-calls-per-day 100] [--bootstrap-server host:port]
  ./scripts/platform.sh ingest poll [--pph 1|--polls-per-hour 1] [--max-calls-per-day 100] [--bootstrap-server host:port]
  ./scripts/platform.sh ingest stop
  ./scripts/platform.sh ingest status
  
  ./scripts/platform.sh bronze consume [--bootstrap-server host:port]
  ./scripts/platform.sh bronze stop
  ./scripts/platform.sh bronze status

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
  REDPANDA_PORT                             Default: 9092
  REDPANDA_BOOTSTRAP_SERVER                 Default: resolved from Azure public IP pip-redpanda

  WORKER_PROJECT                            Default: src/Platform.Worker/Platform.Worker.csproj
  BRONZE_CONSUMER_PROJECT                   Default: src/Platform.BronzeConsumer/Platform.BronzeConsumer.csproj
  BRONZE_CONSUMER_TOPIC_NAME                Default: soccer.raw.ingestion.dev
  BRONZE_CONSUMER_GROUP_ID                  Default: platform-bronze-consumer-dev
  BRONZE_OUTPUT_PATH                        Default: localdata/bronze/raw_ingestion_events.jsonl
  QUARANTINE_OUTPUT_PATH                    Default: localdata/quarantine/raw_ingestion_quarantine.jsonl
  API_FOOTBALL_MAX_CALLS_PER_DAY            Default: 100
  INGEST_DEFAULT_POLLS_PER_HOUR             Default: 1
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

require_positive_integer() {
  local value="$1"
  local name="$2"

  if ! [[ "${value}" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: ${name} must be a positive integer. Received: ${value}" >&2
    exit 1
  fi
}

ensure_runtime_dir() {
  mkdir -p "${RUNTIME_DIR}"
}

worker_pid_is_running() {
  local pid

  if [[ ! -f "${INGEST_PID_FILE}" ]]; then
    return 1
  fi

  pid="$(cat "${INGEST_PID_FILE}")"

  if [[ -z "${pid}" ]]; then
    return 1
  fi

  kill -0 "${pid}" >/dev/null 2>&1
}

bronze_consumer_pid_is_running() {
  local pid

  if [[ ! -f "${BRONZE_CONSUMER_PID_FILE}" ]]; then
    return 1
  fi

  pid="$(cat "${BRONZE_CONSUMER_PID_FILE}")"

  if [[ -z "${pid}" ]]; then
    return 1
  fi

  kill -0 "${pid}" >/dev/null 2>&1
}

parse_ingest_options() {
  INGEST_POLLS_PER_HOUR="${INGEST_DEFAULT_POLLS_PER_HOUR}"
  INGEST_MAX_CALLS_PER_DAY="${API_FOOTBALL_MAX_CALLS_PER_DAY}"
  INGEST_BOOTSTRAP_SERVER="${REDPANDA_BOOTSTRAP_SERVER:-}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pph|--polls-per-hour)
        if [[ $# -lt 2 ]]; then
          echo "ERROR: $1 requires a value." >&2
          exit 1
        fi

        INGEST_POLLS_PER_HOUR="$2"
        shift 2
        ;;
      --max-calls-per-day)
        if [[ $# -lt 2 ]]; then
          echo "ERROR: $1 requires a value." >&2
          exit 1
        fi

        INGEST_MAX_CALLS_PER_DAY="$2"
        shift 2
        ;;
      --bootstrap-server)
        if [[ $# -lt 2 ]]; then
          echo "ERROR: $1 requires a value." >&2
          exit 1
        fi

        INGEST_BOOTSTRAP_SERVER="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown ingest option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  require_positive_integer "${INGEST_POLLS_PER_HOUR}" "polls per hour"
  require_positive_integer "${INGEST_MAX_CALLS_PER_DAY}" "max calls per day"
}

validate_polling_budget() {
  local polls_per_hour="$1"
  local max_calls_per_day="$2"
  local projected_daily_polls
  local safe_max_polls_per_hour

  projected_daily_polls=$((polls_per_hour * 24))
  safe_max_polls_per_hour=$((max_calls_per_day / 24))

  if (( projected_daily_polls > max_calls_per_day )); then
    echo "ERROR: --pph ${polls_per_hour} would allow up to ${projected_daily_polls} polls/day." >&2
    echo "Daily max is ${max_calls_per_day}." >&2
    echo "Choose a lower polling frequency. With max ${max_calls_per_day}, normal safe max is ${safe_max_polls_per_hour} polls/hour." >&2
    exit 1
  fi
}

poll_interval_seconds() {
  local polls_per_hour="$1"

  echo $((3600 / polls_per_hour))
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

resolve_redpanda_bootstrap_server() {
  local resource_group_name
  local redpanda_ip

  if [[ -n "${INGEST_BOOTSTRAP_SERVER:-}" ]]; then
    printf '%s\n' "${INGEST_BOOTSTRAP_SERVER}"
    return
  fi

  require_command az

  resource_group_name="$(azure_resource_group)"

  if [[ -z "${resource_group_name}" ]]; then
    echo "ERROR: Could not resolve Azure resource group." >&2
    echo "Set AZURE_RESOURCE_GROUP or define resource_group_name in ${STAGING_TFVARS}." >&2
    exit 1
  fi

  redpanda_ip="$(
    az network public-ip show \
      --resource-group "${resource_group_name}" \
      --name "${REDPANDA_PUBLIC_IP_NAME}" \
      --query ipAddress \
      --output tsv
  )"

  if [[ -z "${redpanda_ip}" ]]; then
    echo "ERROR: Could not resolve Redpanda public IP: ${REDPANDA_PUBLIC_IP_NAME}" >&2
    exit 1
  fi

  printf '%s:%s\n' "${redpanda_ip}" "${REDPANDA_PORT}"
}

verify_tcp_endpoint() {
  local endpoint="$1"
  local host
  local port

  host="${endpoint%:*}"
  port="${endpoint##*:}"

  if [[ -z "${host}" || -z "${port}" || "${host}" == "${port}" ]]; then
    echo "ERROR: Invalid TCP endpoint: ${endpoint}" >&2
    echo "Expected format: host:port" >&2
    exit 1
  fi

  require_command nc

  echo "Verifying TCP connectivity to ${host}:${port}..."

  if ! nc -vz "${host}" "${port}" >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to ${host}:${port}." >&2
    echo "Confirm Redpanda is running and that the network/security rules allow access." >&2
    exit 1
  fi

  echo "TCP connectivity verified: ${host}:${port}"
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

  for attempt in {1..12}; do
    if curl \
      --fail \
      --silent \
      --show-error \
      --location \
      "https://${default_hostname}/health" \
      >/dev/null; then
      echo "Platform.Api health endpoint is healthy."
      return
    fi

    echo "Platform.Api health endpoint not ready yet. Retry ${attempt}/12..."
    sleep 5
  done

  echo "ERROR: Platform.Api health endpoint did not become healthy: https://${default_hostname}/health" >&2
  exit 1
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

ingest_once() {
  local bootstrap_server

  parse_ingest_options "$@"

  require_command dotnet
  require_file "${WORKER_PROJECT}"

  bootstrap_server="$(resolve_redpanda_bootstrap_server)"
  verify_tcp_endpoint "${bootstrap_server}"

  echo "Running one controlled ingestion pass."
  echo "Worker project: ${WORKER_PROJECT}"
  echo "Kafka bootstrap server: ${bootstrap_server}"
  echo "Max API-Football calls per day: ${INGEST_MAX_CALLS_PER_DAY}"

  Kafka__BootstrapServers="${bootstrap_server}" \
  API_FOOTBALL_CALL_LEDGER_PATH="${ROOT_DIR}/localdata/api-football-call-ledger.json" \
  dotnet run \
    --project "${WORKER_PROJECT}" \
    -- \
    --mode once \
    --max-calls-per-day "${INGEST_MAX_CALLS_PER_DAY}"
}

ingest_poll() {
  local interval_seconds
  local bootstrap_server

  parse_ingest_options "$@"

  require_command dotnet
  require_file "${WORKER_PROJECT}"
  ensure_runtime_dir
  validate_polling_budget "${INGEST_POLLS_PER_HOUR}" "${INGEST_MAX_CALLS_PER_DAY}"

  bootstrap_server="$(resolve_redpanda_bootstrap_server)"
  verify_tcp_endpoint "${bootstrap_server}"

  interval_seconds="$(poll_interval_seconds "${INGEST_POLLS_PER_HOUR}")"

  if worker_pid_is_running; then
    echo "ERROR: Ingestion polling already appears to be running." >&2
    echo "PID file: ${INGEST_PID_FILE}" >&2
    echo "Run './scripts/platform.sh ingest status' or './scripts/platform.sh ingest stop'." >&2
    exit 1
  fi

  echo "Starting ingestion polling."
  echo "Worker project: ${WORKER_PROJECT}"
  echo "Kafka bootstrap server: ${bootstrap_server}"
  echo "Polls per hour: ${INGEST_POLLS_PER_HOUR}"
  echo "Poll interval seconds: ${interval_seconds}"
  echo "Max API-Football calls per day: ${INGEST_MAX_CALLS_PER_DAY}"
  echo "Log file: ${INGEST_LOG_FILE}"

  Kafka__BootstrapServers="${bootstrap_server}" \
  API_FOOTBALL_CALL_LEDGER_PATH="${ROOT_DIR}/localdata/api-football-call-ledger.json" \
  nohup dotnet run \
    --project "${WORKER_PROJECT}" \
    -- \
    --mode poll \
    --poll-interval-seconds "${interval_seconds}" \
    --max-calls-per-day "${INGEST_MAX_CALLS_PER_DAY}" \
    >"${INGEST_LOG_FILE}" 2>&1 &

  echo "$!" > "${INGEST_PID_FILE}"

  cat > "${INGEST_STATE_FILE}" <<EOF_INGEST_STATE
MODE=poll
KAFKA_BOOTSTRAP_SERVER=${bootstrap_server}
POLLS_PER_HOUR=${INGEST_POLLS_PER_HOUR}
POLL_INTERVAL_SECONDS=${interval_seconds}
MAX_CALLS_PER_DAY=${INGEST_MAX_CALLS_PER_DAY}
STARTED_AT_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
WORKER_PROJECT=${WORKER_PROJECT}
LOG_FILE=${INGEST_LOG_FILE}
PID_FILE=${INGEST_PID_FILE}
EOF_INGEST_STATE

  echo "Ingestion polling started with PID $(cat "${INGEST_PID_FILE}")."
}

ingest_stop() {
  local pid

  if ! worker_pid_is_running; then
    echo "Ingestion polling is not running."
    rm -f "${INGEST_PID_FILE}"
    return
  fi

  pid="$(cat "${INGEST_PID_FILE}")"

  echo "Stopping ingestion polling PID ${pid}..."
  kill "${pid}"

  for attempt in {1..10}; do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      rm -f "${INGEST_PID_FILE}"
      echo "Ingestion polling stopped."
      return
    fi

    sleep 1
  done

  echo "WARNING: Process did not stop after graceful termination. Sending SIGKILL." >&2
  kill -9 "${pid}" >/dev/null 2>&1 || true
  rm -f "${INGEST_PID_FILE}"
  echo "Ingestion polling stopped."
}

ingest_status() {
  echo "Ingestion status"
  echo "----------------"

  if worker_pid_is_running; then
    echo "State: running"
    echo "PID: $(cat "${INGEST_PID_FILE}")"
  else
    echo "State: stopped"

    if [[ -f "${INGEST_PID_FILE}" ]]; then
      echo "Stale PID file found: ${INGEST_PID_FILE}"
    fi
  fi

  if [[ -f "${INGEST_STATE_FILE}" ]]; then
    echo
    echo "Last polling configuration:"
    cat "${INGEST_STATE_FILE}"
  fi

  if [[ -f "${INGEST_LOG_FILE}" ]]; then
    echo
    echo "Recent worker log:"
    tail -n 25 "${INGEST_LOG_FILE}"
  fi
}

ingest_platform() {
  local ingest_action="${1:-}"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "${ingest_action}" in
    once)
      ingest_once "$@"
      ;;
    poll)
      ingest_poll "$@"
      ;;
    stop)
      ingest_stop
      ;;
    status)
      ingest_status
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "ERROR: Unknown ingest action: ${ingest_action}" >&2
      usage
      exit 1
      ;;
  esac
}

bronze_consume() {
  local bootstrap_server

  parse_ingest_options "$@"

  require_command dotnet
  require_file "${BRONZE_CONSUMER_PROJECT}"
  ensure_runtime_dir

  bootstrap_server="$(resolve_redpanda_bootstrap_server)"
  verify_tcp_endpoint "${bootstrap_server}"

  if bronze_consumer_pid_is_running; then
    echo "ERROR: Bronze consumer already appears to be running." >&2
    echo "PID file: ${BRONZE_CONSUMER_PID_FILE}" >&2
    echo "Run './scripts/platform.sh bronze status' or './scripts/platform.sh bronze stop'." >&2
    exit 1
  fi

  echo "Starting Bronze consumer."
  echo "Bronze consumer project: ${BRONZE_CONSUMER_PROJECT}"
  echo "Kafka bootstrap server: ${bootstrap_server}"
  echo "Topic name: ${BRONZE_CONSUMER_TOPIC_NAME}"
  echo "Consumer group: ${BRONZE_CONSUMER_GROUP_ID}"
  echo "Bronze output path: ${BRONZE_OUTPUT_PATH}"
  echo "Quarantine output path: ${QUARANTINE_OUTPUT_PATH}"
  echo "Log file: ${BRONZE_CONSUMER_LOG_FILE}"

  BronzeConsumer__BootstrapServers="${bootstrap_server}" \
  BronzeConsumer__TopicName="${BRONZE_CONSUMER_TOPIC_NAME}" \
  BronzeConsumer__ConsumerGroupId="${BRONZE_CONSUMER_GROUP_ID}" \
  BronzeConsumer__BronzeOutputPath="${BRONZE_OUTPUT_PATH}" \
  BronzeConsumer__QuarantineOutputPath="${QUARANTINE_OUTPUT_PATH}" \
  nohup dotnet run \
    --project "${BRONZE_CONSUMER_PROJECT}" \
    >"${BRONZE_CONSUMER_LOG_FILE}" 2>&1 &

  echo "$!" > "${BRONZE_CONSUMER_PID_FILE}"

  cat > "${BRONZE_CONSUMER_STATE_FILE}" <<EOF_BRONZE_CONSUMER_STATE
MODE=consume
KAFKA_BOOTSTRAP_SERVER=${bootstrap_server}
TOPIC_NAME=${BRONZE_CONSUMER_TOPIC_NAME}
CONSUMER_GROUP_ID=${BRONZE_CONSUMER_GROUP_ID}
BRONZE_OUTPUT_PATH=${BRONZE_OUTPUT_PATH}
QUARANTINE_OUTPUT_PATH=${QUARANTINE_OUTPUT_PATH}
STARTED_AT_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BRONZE_CONSUMER_PROJECT=${BRONZE_CONSUMER_PROJECT}
LOG_FILE=${BRONZE_CONSUMER_LOG_FILE}
PID_FILE=${BRONZE_CONSUMER_PID_FILE}
EOF_BRONZE_CONSUMER_STATE

  echo "Bronze consumer started with PID $(cat "${BRONZE_CONSUMER_PID_FILE}")."
}

bronze_stop() {
  local pid

  if ! bronze_consumer_pid_is_running; then
    echo "Bronze consumer is not running."
    rm -f "${BRONZE_CONSUMER_PID_FILE}"
    return
  fi

  pid="$(cat "${BRONZE_CONSUMER_PID_FILE}")"

  echo "Stopping Bronze consumer PID ${pid}..."
  kill "${pid}"

  for attempt in {1..10}; do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      rm -f "${BRONZE_CONSUMER_PID_FILE}"
      echo "Bronze consumer stopped."
      return
    fi

    sleep 1
  done

  echo "WARNING: Bronze consumer did not stop after graceful termination. Sending SIGKILL." >&2
  kill -9 "${pid}" >/dev/null 2>&1 || true
  rm -f "${BRONZE_CONSUMER_PID_FILE}"
  echo "Bronze consumer stopped."
}

bronze_status() {
  echo "Bronze consumer status"
  echo "----------------------"

  if bronze_consumer_pid_is_running; then
    echo "State: running"
    echo "PID: $(cat "${BRONZE_CONSUMER_PID_FILE}")"
  else
    echo "State: stopped"

    if [[ -f "${BRONZE_CONSUMER_PID_FILE}" ]]; then
      echo "Stale PID file found: ${BRONZE_CONSUMER_PID_FILE}"
    fi
  fi

  if [[ -f "${BRONZE_CONSUMER_STATE_FILE}" ]]; then
    echo
    echo "Last Bronze consumer configuration:"
    cat "${BRONZE_CONSUMER_STATE_FILE}"
  fi

  if [[ -f "${BRONZE_CONSUMER_LOG_FILE}" ]]; then
    echo
    echo "Recent Bronze consumer log:"
    tail -n 25 "${BRONZE_CONSUMER_LOG_FILE}"
  fi

  echo
  echo "Bronze output:"
  if [[ -f "${BRONZE_OUTPUT_PATH}" ]]; then
    tail -n 5 "${BRONZE_OUTPUT_PATH}"
  else
    echo "No Bronze output file found: ${BRONZE_OUTPUT_PATH}"
  fi

  echo
  echo "Quarantine output:"
  if [[ -f "${QUARANTINE_OUTPUT_PATH}" ]]; then
    tail -n 5 "${QUARANTINE_OUTPUT_PATH}"
  else
    echo "No quarantine output file found: ${QUARANTINE_OUTPUT_PATH}"
  fi
}

bronze_platform() {
  local bronze_action="${1:-}"

  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "${bronze_action}" in
    consume)
      bronze_consume "$@"
      ;;
    stop)
      bronze_stop
      ;;
    status)
      bronze_status
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "ERROR: Unknown bronze action: ${bronze_action}" >&2
      usage
      exit 1
      ;;
  esac
}

main() {
  local action="${1:-}"

  if [[ $# -gt 0 ]]; then
    shift
  fi

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
    ingest)
      ingest_platform "$@"
      ;;
    bronze)
      bronze_platform "$@"
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
