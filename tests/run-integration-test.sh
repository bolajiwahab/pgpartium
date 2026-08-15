#!/bin/bash

set -euo pipefail

compose_file="tests/docker-compose-integration.yaml"

docker compose -f ${compose_file} build --no-cache
docker compose -f ${compose_file} down -v --remove-orphans
docker compose -f ${compose_file} up --force-recreate --abort-on-container-exit --quiet-pull --remove-orphans
docker compose -f ${compose_file} down -v --remove-orphans
