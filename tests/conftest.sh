#!/bin/bash

function teardown() {
    psql --no-psqlrc --quiet --variable ON_ERROR_STOP=1 <<SQL
ALTER SYSTEM SET mock.now = 'disabled';
SQL
    pg_ctl reload
}
