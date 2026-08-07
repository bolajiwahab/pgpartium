#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# shellcheck source=tests/conftest.sh
source "${BATS_TEST_DIRNAME}/conftest.sh"

shopt -s globstar nullglob

function cleanup() {
    local teardown_file="${1}"
    local result="${2}"
    local test_db="${3:-}"

    if [[ -n "${test_db}" ]]; then
        dropdb --if-exists "${test_db}"
    fi

    if [[ -f "${teardown_file}" ]]; then
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${teardown_file}"
    fi

    rm -f "${result}"
}

function run_config_file() {
    local config_file="${1}"
    local config_file_name
    local fixture
    local expected
    local result
    local setup_file
    local teardown_file
    local test_db="pgpartix_expire_test_$$"

    fixture="$(dirname "${config_file}")"
    config_file_name="${config_file%.yaml}"
    config_file_name="${config_file_name%.yml}"
    expected="${config_file_name}.expected.sql"
    result="${fixture}/pgpartix_output.sql"
    setup_file="${fixture}/setup.sql"
    teardown_file="${fixture}/teardown.sql"

    trap 'cleanup "${teardown_file}" "${result}" "${test_db}"' ERR INT TERM

    if [[ -f "${setup_file}" && ! -f "${teardown_file}" ]]; then
        echo "Missing ${teardown_file} for ${setup_file}" >&2
        exit 1
    fi

    if [[ -f "${setup_file}" ]]; then
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${setup_file}"
        pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload
    fi

    pgp-expire-partitions -c "${config_file}"
    diff -u "${expected}" "${result}"

    # Validate the migration produced through the CLI by executing it in an
    # isolated copy of the fixture database.
    createdb --template="${PGP_DATABASE}" "${test_db}"
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname "${test_db}" --file "${result}"

    cleanup "${teardown_file}" "${result}" "${test_db}"
    trap - ERR INT TERM
}

function cleanup_config_directory() {
    local fixture="${1}"
    local test_db="${2:-}"

    if [[ -n "${test_db}" ]]; then
        dropdb --if-exists "${test_db}"
    fi

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"
    rm -f "${fixture}/events.sql" "${fixture}/measurements.sql"
}

function run_config_directory() {
    local fixture="${1}"
    local expected
    local result
    local test_db="pgpartix_expire_test_$$"

    trap 'cleanup_config_directory "${fixture}" "${test_db}"' ERR INT TERM

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    pgp-expire-partitions -c "${fixture}/configs"

    createdb --template="${PGP_DATABASE}" "${test_db}"

    for expected in "${fixture}"/*.expected.sql; do
        result="${expected%.expected.sql}.sql"
        diff -u "${expected}" "${result}"
        psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname "${test_db}" --file "${result}"
    done

    cleanup_config_directory "${fixture}" "${test_db}"
    trap - ERR INT TERM
}

@test "pgp-expire-partitions shows help" {
    run pgp-expire-partitions -h

    [ "${status}" -eq 0 ]
    grep -Fq "expire partitions" <<< "${output}"
}

@test "pgp-expire-partitions rejects database CLI options" {
    run pgp-expire-partitions -u "${PGP_USER}"

    [ "${status}" -eq 1 ]
    grep -Fq "expire partitions" <<< "${output}"
}

@test "pgp-expire-partitions uses local connection defaults and silences successful formatting" {
    local fixture="tests/fixtures/expire_partitions/defaults"
    local result="${fixture}/pgpartix_output.sql"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run env \
        -u PGP_USER \
        -u PGP_PASSWORD \
        -u PGP_DATABASE \
        -u PGP_HOST \
        -u PGP_PORT \
        pgp-expire-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 0 ]
    run ! grep -Fq "file(s) reformatted" <<< "${output}"
    diff -u "${fixture}/config.expected.sql" "${result}"
    rm -f "${result}"
}

@test "pgp-expire-partitions requires a config" {
    run pgp-expire-partitions

    [ "${status}" -eq 1 ]
    grep -Fq "expire partitions" <<< "${output}"
}

@test "pgp-expire-partitions rejects a missing config path" {
    run pgp-expire-partitions -c "${BATS_TEST_TMPDIR}/missing.yaml"

    [ "${status}" -eq 1 ]
    grep -Fq "does not exist" <<< "${output}"
}

@test "pgp-expire-partitions rejects invalid config" {
    local config="${BATS_TEST_TMPDIR}/invalid.yaml"
    printf '%s\n' '---' 'lifecycle:' '  tables: []' > "${config}"

    run pgp-expire-partitions -c "${config}"

    [ "${status}" -eq 1 ]
    grep -Fq "Config file ${config} is invalid" <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
}

@test "pgp-expire-partitions processes a config directory" {
    local fixture="tests/fixtures/expire_partitions/config_directory"

    run run_config_directory "${fixture}"

    [ "${status}" -eq 0 ]
    grep -Fq "Applied configs from ${fixture}/configs" <<< "${output}"
}

@test "pgp-expire-partitions applies global config and table overrides" {
    local fixture="tests/fixtures/expire_partitions/global_config"
    local inherited_result="${fixture}/expire_global_test_inherited_events.sql"
    local overridden_result="${fixture}/detach_override_test_overridden_events.sql"
    local test_db="pgpartix_expire_global_test_$$"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    pgp-expire-partitions -c "${fixture}/config.yaml"

    diff -u "${fixture}/expire_global_test_inherited_events.expected.sql" "${inherited_result}"
    diff -u "${fixture}/detach_override_test_overridden_events.expected.sql" "${overridden_result}"

    createdb --template="${PGP_DATABASE}" "${test_db}"
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname "${test_db}" --file "${inherited_result}"
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --dbname "${test_db}" --file "${overridden_result}"
    dropdb "${test_db}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"
    rm -f "${inherited_result}" "${overridden_result}"
}

@test "pgp-expire-partitions handles an empty result" {
    local fixture="tests/fixtures/expire_partitions/empty_result"
    local result="${fixture}/pgpartix_output.sql"
    local run_status

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run pgp-expire-partitions -c "${fixture}/config.yaml"
    run_status="${status}"

    cleanup "${fixture}/teardown.sql" "${result}"

    [ "${run_status}" -eq 0 ]
    [ ! -e "${result}" ]
}

@test "pgp-expire-partitions reports database failures" {
    local fixture="tests/fixtures/expire_partitions/database_failure"
    local expected="${fixture}/pgpartix_output.expected.sql"
    local result="${fixture}/pgpartix_output.sql"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"

    run pgp-expire-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 2 table(s)" <<< "${output}"
    grep -Fq 'table "test"."missing_notifications" does not exist' <<< "${output}"
    grep -Fq 'table "test"."notifications" is not partitioned' <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
    diff -u "${expected}" "${result}"
    rm -f "${result}"
}

@test "pgp-expire-partitions manages formatter failures" {
    local fixture="tests/fixtures/expire_partitions/defaults"
    local fake_bin="${BATS_TEST_TMPDIR}/bin"

    mkdir -p "${fake_bin}"
    printf '%s\n' '#!/bin/bash' 'echo "formatter internals" >&2' 'exit 1' > "${fake_bin}/pgrubic"
    chmod +x "${fake_bin}/pgrubic"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run env PATH="${fake_bin}:${PATH}" pgp-expire-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 1 table(s)" <<< "${output}"
    grep -Fq "failed to format generated SQL" <<< "${output}"
    grep -Fq "formatter internals" <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
    [ ! -e "${fixture}/pgpartix_output.sql" ]
}

for fixture in tests/fixtures/expire_partitions/**/*.{yaml,yml}; do
    fixture_name="${fixture%.yaml}"
    fixture_name="${fixture_name%.yml}"
    expected="${fixture_name}.expected.sql"
    if [[ -f "${expected}" ]]; then
        directory="$(basename "$(dirname "${fixture}")")"
        bats_test_function \
            --description "testing ${directory} with $(basename "${fixture}")" \
            -- run_config_file "${fixture}"
    fi
done
