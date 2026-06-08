#!/usr/bin/env bats

run_fixture() {
    local fixture="$1"
    local base="${fixture%.yaml}"

    pgp-make-partitions -c "$fixture"

    echo "running diff"
    diff -u \
        "${base}.expected" \
        "${base}.result"

    # PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" psql -v ON_ERROR_STOP=1 -f "${base}.result"
    echo "running psql"
    # PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" psql -X -v ON_ERROR_STOP=1 -v AUTOCOMMIT=off -f "${base}.result"
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" createdb --template="${PGP_DATABASE}" pgpartium_test_$$
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" psql -d pgpartium_test_$$ -X -v ON_ERROR_STOP=1 -f "${base}.result"
    PGUSER="${PGP_USER}" PGPASSWORD="${PGP_PASSWORD}" dropdb pgpartium_test_$$

    # [ "$status" -eq 0 ]
}

for fixture in tests/fixtures/make_partitions/*.yaml; do
    bats_test_function \
        --description "testing make_partitions with $(basename "${fixture%.yaml}")" \
        -- run_fixture "$fixture"
done

# perform_test() {
#     # fill the actual test code here
# }

# for f in ./*; do
#   bats_test_function --description "testing $f" --tags foo -- perform_test $f
# done
