#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
DATABRICKS_DIR="${ROOT_DIR}/databricks"

TARGET="${DATABRICKS_TARGET:-staging}"
BUNDLE_JOB="${DATABRICKS_BUNDLE_JOB:-medallion-slice}"

usage() {
  cat <<EOF
Usage:
  ./scripts/platform.sh plan
  ./scripts/platform.sh up
  ./scripts/platform.sh down
  ./scripts/platform.sh verify
  ./scripts/platform.sh resume

Environment overrides:
  DATABRICKS_TARGET       Default: staging
  DATABRICKS_BUNDLE_JOB   Default: medallion-slice
EOF
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

run_databricks_bundle_validate() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Validating Databricks bundle for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"
    databricks bundle validate -t "${TARGET}"
  )
}

run_databricks_bundle_deploy() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Deploying Databricks bundle for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"
    databricks bundle deploy -t "${TARGET}"
  )
}

run_databricks_bundle_run() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Running Databricks bundle job: ${BUNDLE_JOB}"

  (
    cd "${DATABRICKS_DIR}"

    if databricks bundle run -t "${TARGET}" "${BUNDLE_JOB}"; then
      return 0
    fi

    echo "Retrying Databricks bundle run with alternate CLI argument ordering..."

    databricks bundle run "${BUNDLE_JOB}" -t "${TARGET}"
  )
}

run_databricks_bundle_destroy() {
  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  echo "Destroying Databricks bundle resources for target: ${TARGET}"

  (
    cd "${DATABRICKS_DIR}"

    if databricks bundle destroy -t "${TARGET}" --auto-approve; then
      return 0
    fi

    echo "WARNING: Databricks bundle destroy failed or is unsupported in this context." >&2
    echo "Continuing teardown so local/platform cleanup can proceed." >&2
  )
}

plan_platform() {
  require_file "${SCRIPTS_DIR}/up-staging.sh"

  echo "Planning staging infrastructure..."
  "${SCRIPTS_DIR}/up-staging.sh" plan
}

up_platform() {
  require_file "${SCRIPTS_DIR}/up-staging.sh"
  require_file "${SCRIPTS_DIR}/up-redpanda.sh"

  echo "Applying staging infrastructure..."
  "${SCRIPTS_DIR}/up-staging.sh" apply

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

verify_platform() {
  echo "Verifying platform..."

  require_command databricks
  require_dir "${DATABRICKS_DIR}"

  run_databricks_bundle_validate

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

