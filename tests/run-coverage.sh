#!/bin/bash

set -euo pipefail

MIN_COVERAGE="${MIN_COVERAGE:-80}"
COVERAGE_DIR="${COVERAGE_DIR:-coverage}"

pgp-start

kcov \
  --clean \
  --dump-summary \
  --limits=50,100 \
  --include-pattern=pgp- \
  --include-path=/usr/local/bin/ \
  "${COVERAGE_DIR}" \
  bats tests/conftest.sh

coverage_file=$(find "${COVERAGE_DIR}" -name coverage.json -print -quit)

if [[ -z "${coverage_file}" ]]; then
  echo "coverage.json not found"
  exit 1
fi

coverage=$(yq -r '.percent_covered' "${coverage_file}")

if [[ -z "${coverage}" || "${coverage}" == "null" ]]; then
  echo "Could not determine coverage percentage"
  exit 1
fi

printf 'Coverage: %.2f%%\n' "${coverage}"

awk -v c="${coverage}" -v min="${MIN_COVERAGE}" '
BEGIN {
  if (c < min) {
    printf "Coverage %.2f%% is below required %.0f%%\n", c, min
    exit 1
  }
}'

exit 0
