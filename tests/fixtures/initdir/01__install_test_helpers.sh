#!/bin/bash

set -euo pipefail

echo "INFO: Installing pgtap extension files and required contrib extensions"
apt-get install -y postgresql-"${PGP_PG_MAJOR_VERSION}"-pgtap postgresql-contrib-"${PGP_PG_MAJOR_VERSION}"

echo "INFO: Setting up shellspec"
wget --quiet https://github.com/shellspec/shellspec/archive/"${SHELL_SPEC_VERSION}".tar.gz --output-document=/tmp/shellspec-"${SHELL_SPEC_VERSION}".tar.gz
tar xzf /tmp/shellspec-"${SHELL_SPEC_VERSION}".tar.gz -C /tmp
ln -s /tmp/shellspec-"${SHELL_SPEC_VERSION}"/bin/shellspec /usr/bin/shellspec

echo "INFO: Creating directory for tablespace ${PGP_CLUSTER_NAME}"
mkdir -p /var/lib/postgresql/tablespaces/pgpartium
chown -R postgres:postgres /var/lib/postgresql/tablespaces/pgpartium

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
