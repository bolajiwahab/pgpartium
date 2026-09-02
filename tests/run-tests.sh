#!/bin/bash

set -euo pipefail

if [[ -f /.dockerenv ]]; then
    pgp-start
    exec bats tests/test_*.sh
fi

export PGP_TEST_COMMAND=tests/run-tests.sh

exec tests/run-coverage.sh
