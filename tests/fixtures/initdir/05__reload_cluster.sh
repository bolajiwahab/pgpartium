#!/bin/bash

pg_ctlcluster "${PGP_PG_MAJOR_VERSION}" "${PGP_CLUSTER_NAME}" reload
