#!/usr/bin/env bash
# Convenience wrapper: terraform init + plan for a given environment.
# Usage: ./scripts/plan.sh dev|prod
set -euo pipefail

ENVIRONMENT="${1:?Usage: plan.sh <dev|prod>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT_DIR}/terraform/environments/${ENVIRONMENT}"

if [[ ! -d "${ENV_DIR}" ]]; then
  echo "Unknown environment '${ENVIRONMENT}'. Expected one of: dev, prod" >&2
  exit 1
fi

cd "${ENV_DIR}"

terraform init -input=false
terraform validate
terraform plan -input=false -out=tfplan.binary

echo
echo "Plan written to ${ENV_DIR}/tfplan.binary"
echo "Review it, then run: ./scripts/apply.sh ${ENVIRONMENT}"
