#!/usr/bin/env bats

shopt -s globstar nullglob

teardown() {
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
ALTER SYSTEM RESET mock.now;
SQL
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload
}

function cleanup() {
    local teardown_file="${1}"
    local test_db="${2}"
    local result="${3}"

    echo "INFO: Cleaning up after error" >&2

    if [[ -f "${teardown_file}" ]]; then
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${teardown_file}"
    fi

    dropdb --if-exists "${test_db}"

    rm -f "${result}"
}

function run_config_file() {
    local config_file="$1"
    local config_file_name
    local config_file_directory
    local expected
    local result
    local setup_file
    local teardown_file
    local test_db="pgpartium_test_$$"

    config_file_directory="$(dirname "${config_file}")"
    config_file_name="${config_file%.yaml}"
    config_file_name="${config_file_name%.yml}"

    expected="${config_file_name}.expected.sql"
    result="${config_file_directory}/pgpartium_output.sql"

    setup_file="${config_file_directory}/setup.sql"
    teardown_file="${config_file_directory}/teardown.sql"

    trap 'cleanup ${teardown_file} ${test_db} ${result}' ERR INT TERM

    if [[ -f "${setup_file}" && ! -f "${teardown_file}" ]]; then
        echo "Missing ${teardown_file} for ${setup_file}" >&2
        exit 1
    fi

    if [[ -f "${setup_file}" ]]; then
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${setup_file}"
        pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload
    fi

    pgp-make-partitions -c "${config_file}"

    diff -u "${expected}" "${result}"

    # Validate generated SQL by executing it against a test database.
    createdb --template="${PGP_DATABASE}" "${test_db}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname "${test_db}" --file "${result}"

    dropdb "${test_db}"

    if [[ -f "${teardown_file}" ]]; then
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${teardown_file}"
    fi

    rm -f "${result}"
}

function run_config_directory() {
    local fixture="$1"
    local expected="${fixture}/expected.sql"
    local result="${fixture}/pgpartium_output.sql"

    pgp-make-partitions -c "${fixture}"

    diff -u \
        "${expected}" \
        "${result}"

    createdb --template="${PGP_DATABASE}" pgpartium_test_$$
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname pgpartium_test_$$ --file "${result}"
    dropdb pgpartium_test_$$

    rm -f "${result}"
}

for fixture in tests/fixtures/make_partitions/**/*.{yaml,yml}; do
    directory="$(basename "$(dirname "${fixture}")")"
    bats_test_function \
        --description "testing ${directory} with $(basename "${fixture}")" \
        -- run_config_file "${fixture}"
done
