#!/usr/bin/env bash
set -euo pipefail

echo "Destroying Redpanda only..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${TF_DIR}"

tofu init -reconfigure

tofu destroy -target=module.redpanda_vm -auto-approve

echo "Redpanda destroyed."

