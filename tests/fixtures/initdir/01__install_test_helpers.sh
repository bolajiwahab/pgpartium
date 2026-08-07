#!/bin/bash

set -euo pipefail

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}"
mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"
chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}_fast"
mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast
chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
