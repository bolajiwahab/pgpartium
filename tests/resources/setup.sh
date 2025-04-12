#!/bin/bash

usage()
{
cat <<-EOF
    ${0##*/}

    Sets up pgtap and other resources.

    OPTIONS:
    -v  the postgres version to use (Required)
    -h  show this help message.

    SAMPLE USAGE:
        ${0##*/} -v 17
EOF
}

while getopts "v:h" OPTION
do
    case $OPTION in
        v)
            PGVERSION="$OPTARG"
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done

set -euo pipefail

PGVERSION=${PGVERSION:-}

# Ensure version is provided
if [[ -z "$PGVERSION" ]]; then
  usage
  exit 1
fi

# Append .0 if PGVERSION is a single-digit version e.g 9
[[ $PGVERSION =~ ^[0-9]$ ]] && PGVERSION+=.0

apt-get install -y postgresql-"${PGVERSION}"-pgtap

echo "Creating tablespace pgpartium"
mkdir -pv /var/lib/postgresql/tablespaces/pgpartium
chown -R postgres:postgres /var/lib/postgresql/tablespaces/pgpartium
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE TABLESPACE pgpartium LOCATION '/var/lib/postgresql/tablespaces/pgpartium';"

echo "Creating pgtap extension"
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE EXTENSION pgtap;"

echo "Setting up schema"
psql -v "ON_ERROR_STOP=1" --quiet --single-transaction --username=postgres --dbname=postgres -f tests/resources/mock.sql -f tests/resources/schema.sql

echo "Setting up infra"
pg-setup-infra
