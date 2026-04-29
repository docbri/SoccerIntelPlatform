#!/usr/bin/env bash
set -euo pipefail

echo "Bringing up Redpanda (staging)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/env/staging"

cd "${TF_DIR}"

echo "Initializing..."
tofu init -reconfigure

echo "Applying Redpanda VM..."
tofu apply -auto-approve

echo "Validating Redpanda VM exists in state..."
if ! tofu state list | grep -q "module.redpanda_vm.azurerm_linux_virtual_machine.this"; then
  echo "ERROR: Redpanda VM not found in state after apply"
  exit 1
fi

echo "Validating redpanda_public_ip output exists..."
if ! tofu output -json | grep -q "redpanda_public_ip"; then
  echo "ERROR: Output redpanda_public_ip not found"
  exit 1
fi

echo "Fetching public IP..."
PUBLIC_IP=$(tofu output -raw redpanda_public_ip)

echo "Redpanda VM Public IP: ${PUBLIC_IP}"

echo "Waiting for SSH..."
until ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no azureuser@"${PUBLIC_IP}" "echo ready" 2>/dev/null; do
  echo "Waiting for SSH..."
  sleep 5
done

echo "Installing Docker + running Redpanda..."

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no azureuser@"${PUBLIC_IP}" <<EOF
sudo apt update
sudo apt install -y docker.io

sudo docker rm -f redpanda 2>/dev/null || true

sudo docker run -d --name redpanda \
  --restart unless-stopped \
  -p 9092:9092 \
  docker.redpanda.com/redpandadata/redpanda:latest \
  redpanda start \
  --overprovisioned \
  --smp 1 \
  --memory 1G \
  --reserve-memory 0M \
  --node-id 0 \
  --check=false \
  --kafka-addr PLAINTEXT://0.0.0.0:9092 \
  --advertise-kafka-addr PLAINTEXT://${PUBLIC_IP}:9092
EOF

echo "Redpanda is up at ${PUBLIC_IP}:9092"
