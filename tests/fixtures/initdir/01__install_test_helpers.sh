#!/bin/bash

set -euo pipefail

echo "INFO: Setting up mock timestamp"

psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
ALTER SYSTEM SET mock.now = 'disabled';
ALTER SYSTEM SET search_path = mock, pg_catalog, public;
SQL

pg_ctl reload

echo "INFO: Creating test tablespace directories"
mkdir -p /var/lib/pgpartix/tablespaces/pgpartix
mkdir -p /var/lib/pgpartix/tablespaces/pgpartix_fast

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure
