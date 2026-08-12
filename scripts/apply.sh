#!/usr/bin/env bash
# Convenience wrapper: terraform apply the plan produced by plan.sh.
# Usage: ./scripts/apply.sh dev|prod
set -euo pipefail

ENVIRONMENT="${1:?Usage: apply.sh <dev|prod>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT_DIR}/terraform/environments/${ENVIRONMENT}"
PLAN_FILE="${ENV_DIR}/tfplan.binary"

if [[ ! -f "${PLAN_FILE}" ]]; then
  echo "No saved plan found at ${PLAN_FILE}. Run ./scripts/plan.sh ${ENVIRONMENT} first." >&2
  exit 1
fi

cd "${ENV_DIR}"
terraform apply -input=false "${PLAN_FILE}"
rm -f "${PLAN_FILE}"
