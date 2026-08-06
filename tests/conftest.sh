#!/bin/bash

function teardown() {
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
ALTER SYSTEM RESET mock.now;
SQL
    pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload
}
