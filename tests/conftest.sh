#!/usr/bin/env bats

run_fixture() {
    local fixture="$1"
    local expected="${fixture}/expected.sql"
    local result="${fixture}/pgpartium_output.sql"

    pgp-make-partitions -c "${fixture}"

    diff -u \
        "${expected}" \
        "${result}"

    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" createdb --template="${PGP_DATABASE}" pgpartium_test_$$
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" psql -d pgpartium_test_$$ -X -v ON_ERROR_STOP=1 -f "${result}"
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" dropdb pgpartium_test_$$

    rm -f "${result}"
}

for fixture in tests/fixtures/make_partitions/*; do
    bats_test_function \
        --description "testing make_partitions with $(basename "${fixture}")" \
        -- run_fixture "${fixture}"
done
