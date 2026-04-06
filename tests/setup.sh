#!/bin/bash

set -euo pipefail

echo "INFO: Creating pgtap extension"
apt-get install -y postgresql-"${PGP_PG_MAJOR_VERSION}"-pgtap
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE EXTENSION pgtap;"

# echo "INFO: Setting up shellspec"
# wget --quiet https://github.com/shellspec/shellspec/archive/0.28.1.tar.gz --output-document=/tmp/shellspec-0.28.1.tar.gz
# tar xzf /tmp/shellspec-0.28.1.tar.gz -C /tmp
# ln -s /tmp/shellspec-0.28.1/bin/shellspec /usr/bin/shellspec

echo "INFO: Creating tablespace pgpartium"
mkdir -p /var/lib/postgresql/tablespaces/pgpartium
chown -R postgres:postgres /var/lib/postgresql/tablespaces/pgpartium
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE TABLESPACE pgpartium LOCATION '/var/lib/postgresql/tablespaces/pgpartium';"

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure

# We need to include mock in our search_path
echo "INFO: Adding mock to search_path"
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "ALTER SYSTEM SET search_path = mock, pg_catalog, public;"
pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" pgpartium reload
