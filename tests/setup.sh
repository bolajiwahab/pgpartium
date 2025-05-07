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

while getopts "v:h" option
do
    case "${option}" in
        v)
            pgversion="${OPTARG}"
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done

set -euo pipefail

pgversion=${pgversion:-}

# Ensure version is provided
if [[ -z "${pgversion}" ]]; then
  usage
  exit 1
fi

# Append .0 if pgversion is a single-digit version e.g 9
[[ "${pgversion}" =~ ^[0-9]$ ]] && pgversion+=.0

echo "INFO: Creating pgtap extension"
# apt.postgresql.org.sh -i -v "${pgversion}"
apt-get install -y postgresql-"${pgversion}"-pgtap
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE EXTENSION pgtap;"

echo "INFO: Setting up shellspec"
wget --no-verbose https://github.com/shellspec/shellspec/archive/0.28.1.tar.gz --output-document=/tmp/shellspec-0.28.1.tar.gz
tar xzf /tmp/shellspec-0.28.1.tar.gz -C /tmp
ln -s /tmp/shellspec-0.28.1/bin/shellspec /usr/bin/shellspec

echo "INFO: Creating tablespace pgpartium"
mkdir -p /var/lib/postgresql/tablespaces/pgpartium
chown -R postgres:postgres /var/lib/postgresql/tablespaces/pgpartium
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "CREATE TABLESPACE pgpartium LOCATION '/var/lib/postgresql/tablespaces/pgpartium';"

echo "INFO: Setting up infrastructure"
pgp-setup-infrastructure

# We need to include mock in our search_path
echo "INFO: Adding mock to search_path"
psql -v "ON_ERROR_STOP=1" --quiet --username=postgres --dbname=postgres -c "ALTER SYSTEM SET search_path = mock, public, pg_catalog;"
pg_ctlcluster "${pgversion}" pgpartium reload
