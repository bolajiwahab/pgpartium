#!/bin/bash

set -euo pipefail

echo "INFO: Installing pgtap extension files"
apt-get install -y postgresql-"${PGP_PG_MAJOR_VERSION}"-pgtap

echo "INFO: Setting up shellspec"
wget --quiet https://github.com/shellspec/shellspec/archive/0.28.1.tar.gz --output-document=/tmp/shellspec-0.28.1.tar.gz
tar xzf /tmp/shellspec-0.28.1.tar.gz -C /tmp
ln -s /tmp/shellspec-0.28.1/bin/shellspec /usr/bin/shellspec

echo "INFO: Creating directory for tablespace pgpartium"
mkdir -p /var/lib/postgresql/tablespaces/pgpartium
chown -R postgres:postgres /var/lib/postgresql/tablespaces/pgpartium

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
