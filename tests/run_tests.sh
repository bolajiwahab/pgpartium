#!/bin/bash

set -euo pipefail

MIGRATION_TOOL=${MIGRATION_TOOL:-flyway}

case "${MIGRATION_TOOL}" in
  flyway)
    MIGRATION_TOOL_VERSION="11.8.0"
    MIGRATION_DIRECTORY="tests/migrations/flyway"
    ;;
  go-migrate)
    MIGRATION_TOOL_VERSION="4.18.3"
    MIGRATION_DIRECTORY="tests/migrations/go-migrate"
    ;;
  dbmate)
    MIGRATION_TOOL_VERSION="2.27.0"
    MIGRATION_DIRECTORY="tests/migrations/dbmate"
    ;;
  goose)
    MIGRATION_TOOL_VERSION="3.24.2"
    MIGRATION_DIRECTORY="tests/migrations/goose"
    ;;
  *)
    echo "ERROR: Unsupported migration tool: ${MIGRATION_TOOL}"
    exit 1
    ;;
esac

export MIGRATION_DIRECTORY="${MIGRATION_DIRECTORY}"
export MIGRATION_TOOL="${MIGRATION_TOOL}"
export MIGRATION_TOOL_VERSION="${MIGRATION_TOOL_VERSION}"

compose_file="tests/docker-compose-test.yaml"

docker compose -f ${compose_file} build --no-cache
docker compose -f ${compose_file} down -v --remove-orphans
docker compose -f ${compose_file} up --force-recreate --abort-on-container-exit --quiet-pull --remove-orphans test
docker compose -f ${compose_file} down -v --remove-orphans
