#!/usr/bin/env bats

run_fixture() {
    local fixture="$1"
    local config="$2"
    local expected="$3"
    local result="${fixture}/result.sql"

    pgp-make-partitions -c "${config}"

    echo "running diff"
    diff -u \
        "${expected}" \
        "${fixture}/result.sql"

    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" createdb --template="${PGP_DATABASE}" pgpartium_test_$$
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" psql -d pgpartium_test_$$ -X -v ON_ERROR_STOP=1 -f "${result}"
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" dropdb pgpartium_test_$$

    rm -f "${result}"
}

for fixture in tests/fixtures/make_partitions/*; do
    config="${fixture}/config.yaml"
    expected="${fixture}/expected.sql"

    bats_test_function \
        --description "testing make_partitions with $(basename "${fixture}")" \
        -- run_fixture "${fixture}" "${config}" "${expected}"
done
