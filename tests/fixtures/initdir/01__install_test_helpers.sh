#!/bin/bash

set -euo pipefail

echo "INFO: Installing pgtap extension files and required contrib extensions"
apt-get install -y postgresql-"${PGP_PG_MAJOR_VERSION}"-pgtap postgresql-contrib-"${PGP_PG_MAJOR_VERSION}"

# echo "INFO: Setting up shellspec"
# wget --quiet https://github.com/shellspec/shellspec/archive/"${SHELL_SPEC_VERSION}".tar.gz --output-document=/tmp/shellspec-"${SHELL_SPEC_VERSION}".tar.gz
# tar xzf /tmp/shellspec-"${SHELL_SPEC_VERSION}".tar.gz -C /tmp
# ln -s /tmp/shellspec-"${SHELL_SPEC_VERSION}"/bin/shellspec /usr/bin/shellspec

# sudo apt install bats
# apt-get install -y bats=1.8.2

# bats --version
# npm install @bats-core/bats@1.13.0

git clone https://github.com/bats-core/bats-core.git
cd bats-core
git checkout --quiet v1.13.0   # pin exact version
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
