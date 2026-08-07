#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# shellcheck source=tests/conftest.sh
source "${BATS_TEST_DIRNAME}/conftest.sh"

@test "pgp-start shows help" {
    run pgp-start -h

    [ "${status}" -eq 0 ]
    grep -Fq "Installs major PostgreSQL version" <<< "${output}"
}

@test "pgp-start uses local cluster defaults" {
    local stub_directory="${BATS_TEST_TMPDIR}/bin"
    local apt_marker="${BATS_TEST_TMPDIR}/apt.marker"
    local cluster_marker="${BATS_TEST_TMPDIR}/cluster.marker"

    mkdir -p "${stub_directory}"
    printf "#!/bin/bash\nprintf \"%%s\\\\n\" \"\$*\" > \"\${APT_MARKER}\"\n" > "${stub_directory}/apt.postgresql.org.sh"
    printf "#!/bin/bash\nprintf \"%%s\\\\n\" \"\$*\" > \"\${CLUSTER_MARKER}\"\n" > "${stub_directory}/pg_createcluster"
    chmod +x "${stub_directory}/apt.postgresql.org.sh" "${stub_directory}/pg_createcluster"

    run env \
        -u PGP_PG_MAJOR_VERSION \
        -u PGP_CLUSTER_NAME \
        -u PGP_USER \
        -u PGP_PASSWORD \
        -u PGP_DATABASE \
        -u PGP_HOST \
        -u PGP_PORT \
        -u PGP_INIT_DIR \
        PATH="${stub_directory}:${PATH}" \
        APT_MARKER="${apt_marker}" \
        CLUSTER_MARKER="${cluster_marker}" \
        pgp-start

    [ "${status}" -eq 0 ]
    grep -Fq -- "-i -v 14" "${apt_marker}"
    grep -Fq -- "--start 14 pgpartix --port=5432" "${cluster_marker}"
}

@test "pgp-start rejects unsupported PostgreSQL versions" {
    run pgp-start -v 13

    [ "${status}" -eq 1 ]
    grep -Fq "must be at least 14" <<< "${output}"
}

@test "pgp-start rejects a missing init directory" {
    local stub_directory="${BATS_TEST_TMPDIR}/bin"

    mkdir -p "${stub_directory}"
    printf '#!/bin/bash\nexit 0\n' > "${stub_directory}/apt.postgresql.org.sh"
    printf '#!/bin/bash\nexit 0\n' > "${stub_directory}/pg_createcluster"
    chmod +x "${stub_directory}/apt.postgresql.org.sh" "${stub_directory}/pg_createcluster"

    run env \
        PATH="${stub_directory}:${PATH}" \
        PGP_PG_MAJOR_VERSION=17 \
        pgp-start -i "${BATS_TEST_TMPDIR}/missing"

    [ "${status}" -eq 1 ]
    grep -Fq "does not exist or is not a directory" <<< "${output}"
}

@test "pgp-start applies supported init scripts" {
    local stub_directory="${BATS_TEST_TMPDIR}/bin"
    local init_directory="${BATS_TEST_TMPDIR}/init"
    local executable_marker="${BATS_TEST_TMPDIR}/executable.marker"
    local sourced_marker="${BATS_TEST_TMPDIR}/sourced.marker"

    mkdir -p "${stub_directory}" "${init_directory}"
    printf '#!/bin/bash\nexit 0\n' > "${stub_directory}/apt.postgresql.org.sh"
    printf '#!/bin/bash\nexit 0\n' > "${stub_directory}/pg_createcluster"
    printf '#!/bin/bash\ncat >/dev/null\n' > "${stub_directory}/psql"
    chmod +x "${stub_directory}/apt.postgresql.org.sh" "${stub_directory}/pg_createcluster" "${stub_directory}/psql"

    printf "#!/bin/bash\ntouch \"\${EXECUTABLE_MARKER}\"\n" > "${init_directory}/01__executable.sh"
    printf "touch \"\${SOURCED_MARKER}\"\n" > "${init_directory}/02__sourced.sh"
    printf 'SELECT 1;\n' > "${init_directory}/03__plain.sql"
    printf 'SELECT 1;\n' | gzip > "${init_directory}/04__compressed.sql.gz"
    chmod +x "${init_directory}/01__executable.sh"

    run env \
        PATH="${stub_directory}:${PATH}" \
        PGP_PG_MAJOR_VERSION=17 \
        EXECUTABLE_MARKER="${executable_marker}" \
        SOURCED_MARKER="${sourced_marker}" \
        pgp-start -i "${init_directory}"

    [ "${status}" -eq 0 ]
    [ -e "${executable_marker}" ]
    [ -e "${sourced_marker}" ]
}
