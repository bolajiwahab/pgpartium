#!/bin/bash

set -euo pipefail

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}"
sudo mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"
sudo chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}_fast"
sudo mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast
sudo chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
