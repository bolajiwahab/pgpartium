#!/bin/bash

set -euo pipefail

pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" pgpartium reload
