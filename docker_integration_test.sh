#!/bin/bash

set -euo pipefail

compose_file="docker-compose-test.yml"

docker compose -f ${compose_file} build
docker compose -f ${compose_file} down -v --remove-orphans
docker compose -f ${compose_file} up --force-recreate --abort-on-container-exit --quiet-pull --remove-orphans test
docker compose -f ${compose_file} down -v --remove-orphans
