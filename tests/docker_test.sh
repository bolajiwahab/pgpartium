#!/bin/bash

set -euo pipefail

docker-compose build
docker-compose down -v --remove-orphans
docker-compose up --force-recreate --abort-on-container-exit --quiet-pull --remove-orphans
docker-compose down -v --remove-orphans
