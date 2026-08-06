#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# shellcheck source=tests/conftest.sh
source "${BATS_TEST_DIRNAME}/conftest.sh"

shopt -s globstar nullglob

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
    local expected="${fixture}/config.expected.sql"
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

@test "pgp-make-partitions shows help" {
    run pgp-make-partitions -h

    [ "${status}" -eq 0 ]
    grep -Fq "Make partitions for partitioned tables." <<< "${output}"
}

@test "pgp-make-partitions rejects unknown options" {
    run pgp-make-partitions -z

    [ "${status}" -eq 1 ]
    grep -Fq "Make partitions for partitioned tables." <<< "${output}"
}

@test "pgp-make-partitions uses local connection defaults and silences successful formatting" {
    local fixture="tests/fixtures/make_partitions/defaults"
    local result="${fixture}/pgpartium_output.sql"

    rm -f "${result}"
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run env \
        -u PGP_USER \
        -u PGP_PASSWORD \
        -u PGP_DATABASE \
        -u PGP_HOST \
        -u PGP_PORT \
        pgp-make-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 0 ]
    run ! grep -Fq "file(s) reformatted" <<< "${output}"
    diff -u "${fixture}/config.expected.sql" "${result}"
    rm -f "${result}"
}

@test "pgp-make-partitions rejects a missing config path" {
    run pgp-make-partitions -c "${BATS_TEST_TMPDIR}/missing.yaml"

    [ "${status}" -eq 1 ]
    grep -Fq "does not exist" <<< "${output}"
}

@test "pgp-make-partitions rejects invalid config" {
    local config="${BATS_TEST_TMPDIR}/invalid.yaml"
    printf '%s\n' '---' 'lifecycle:' '  tables: []' > "${config}"

    run pgp-make-partitions -c "${config}"

    [ "${status}" -eq 1 ]
    grep -Fq "is invalid" <<< "${output}"
}

@test "pgp-make-partitions rejects a negative past partition count" {
    local config="${BATS_TEST_TMPDIR}/negative-past.yaml"
    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: transactions
      partition:
        naming:
          template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
        interval: 1 mon
        past: -1
YAML

    run pgp-make-partitions -c "${config}"

    [ "${status}" -eq 1 ]
    grep -Fq "is invalid" <<< "${output}"
    grep -Fq "past" <<< "${output}"
}

@test "pgp-make-partitions rejects a negative future partition count" {
    local config="${BATS_TEST_TMPDIR}/negative-future.yaml"
    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: transactions
      partition:
        naming:
          template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
        interval: 1 mon
        future: -1
YAML

    run pgp-make-partitions -c "${config}"

    [ "${status}" -eq 1 ]
    grep -Fq "is invalid" <<< "${output}"
    grep -Fq "future" <<< "${output}"
}

@test "pgp-make-partitions requires a partition naming template when an interval is specified" {
    local config="${BATS_TEST_TMPDIR}/missing-name-template.yaml"
    local result="${BATS_TEST_TMPDIR}/pgpartium_output.sql"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
CREATE TABLE test.transactions (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
SQL

    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: transactions
      partition:
        interval: 1 mon
YAML

    run pgp-make-partitions -c "${config}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
DROP TABLE test.transactions;
SQL

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 1 table(s)" <<< "${output}"
    grep -Fq "partition name template is required when partition interval is specified" <<< "${output}"
    [ ! -e "${result}" ]
}

@test "pgp-make-partitions skips generation when no partition interval is configured" {
    local config="${BATS_TEST_TMPDIR}/missing-interval.yaml"
    local result="${BATS_TEST_TMPDIR}/pgpartium_output.sql"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
CREATE TABLE test.transactions (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
SQL

    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: transactions
      partition:
        naming:
          template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
YAML

    run pgp-make-partitions -c "${config}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
DROP TABLE test.transactions;
SQL

    [ "${status}" -eq 0 ]
    grep -Fq "No partitions made for test.transactions" <<< "${output}"
    [ ! -e "${result}" ]
}

@test "pgp-make-partitions rejects a missing template table" {
    local config="${BATS_TEST_TMPDIR}/missing-template-table.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
CREATE TABLE test.transactions (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
SQL

    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: transactions
      partition:
        naming:
          template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
        interval: 1 mon
      template:
        schema: test
        name: missing_template
YAML

    run pgp-make-partitions -c "${config}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
DROP TABLE test.transactions;
SQL

    [ "${status}" -eq 1 ]
    grep -Fq "Template table test.missing_template does not exist" <<< "${output}"
}

@test "pgp-make-partitions reports generation failures" {
    local config="${BATS_TEST_TMPDIR}/missing-parent-table.yaml"
    local result="${BATS_TEST_TMPDIR}/pgpartium_output.sql"
    cat > "${config}" <<YAML
---
lifecycle:
  directory: ${BATS_TEST_TMPDIR}
  tables:
    - schema: test
      name: missing_parent
      partition:
        naming:
          template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
        interval: 1 mon
YAML

    run pgp-make-partitions -c "${config}"

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 1 table(s)" <<< "${output}"
    grep -Fq 'table "test"."missing_parent" does not exist' <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
    [ ! -e "${result}" ]
}

@test "pgp-make-partitions reports SQL validation failures through the CLI" {
    local fixture="tests/fixtures/make_partitions/sql_failures"
    local expected="${fixture}/pgpartium_output.expected.sql"
    local result="${fixture}/pgpartium_output.sql"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run pgp-make-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 8 table(s)" <<< "${output}"
    grep -Fq 'is not partitioned' <<< "${output}"
    grep -Fq '"LIST" partitioning is not supported' <<< "${output}"
    grep -Fq 'multi column partitioned tables are not supported' <<< "${output}"
    grep -Fq 'partitioning on data type "text" is not supported' <<< "${output}"
    grep -Fq 'partition schema "missing_schema" does not exist' <<< "${output}"
    grep -Fq 'partition tablespace "missing_tablespace" does not exist' <<< "${output}"
    grep -Fq 'index tablespace "missing_tablespace" does not exist' <<< "${output}"
    grep -Fq 'interval cannot be zero' <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
    diff -u "${expected}" "${result}"
    rm -f "${result}"
}

@test "pgp-make-partitions manages formatter failures" {
    local fixture="tests/fixtures/make_partitions/defaults"
    local fake_bin="${BATS_TEST_TMPDIR}/bin"
    local result="${fixture}/pgpartium_output.sql"

    rm -f "${result}"
    mkdir -p "${fake_bin}"
    printf '%s\n' '#!/bin/bash' 'echo "formatter internals" >&2' 'exit 1' > "${fake_bin}/pgrubic"
    chmod +x "${fake_bin}/pgrubic"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run env PATH="${fake_bin}:${PATH}" pgp-make-partitions -c "${fixture}/config.yaml"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 1 ]
    grep -Fq "failed for 1 table(s)" <<< "${output}"
    grep -Fq "failed to format generated SQL" <<< "${output}"
    grep -Fq "formatter internals" <<< "${output}"
    run ! grep -Fq "Traceback" <<< "${output}"
    [ ! -e "${result}" ]
}

@test "pgp-make-partitions processes a config directory" {
    local fixture="tests/fixtures/make_partitions/shared_output_file"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    run run_config_directory "${fixture}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${status}" -eq 0 ]
}

@test "pgp-make-partitions handles an empty result" {
    local fixture="tests/fixtures/make_partitions/defaults"
    local result="${fixture}/pgpartium_output.sql"
    local run_status

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/setup.sql"
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload

    pgp-make-partitions -c "${fixture}/config.yaml"
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${result}"
    rm -f "${result}"

    run pgp-make-partitions -c "${fixture}/config.yaml"
    run_status="${status}"

    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 --file "${fixture}/teardown.sql"

    [ "${run_status}" -eq 0 ]
    [ ! -e "${result}" ]
}

for fixture in tests/fixtures/make_partitions/**/*.{yaml,yml}; do
    [[ "${fixture}" == */sql_failures/* ]] && continue
    directory="$(basename "$(dirname "${fixture}")")"
    bats_test_function \
        --description "testing ${directory} with $(basename "${fixture}")" \
        -- run_config_file "${fixture}"
done
