#!/bin/bash

set -euo pipefail

git clone https://github.com/bats-core/bats-core.git
cd bats-core
git checkout --quiet "${BATS_CORE_VERSION}"
./install.sh /usr/local
bats --version

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}"
mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"
chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}_fast"
mkdir -p /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast
chown -R postgres:postgres /var/lib/postgresql/tablespaces/"${PGP_CLUSTER_NAME}"_fast

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
