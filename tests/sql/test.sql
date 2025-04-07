-- Turn off echo and keep things quiet.
\unset ECHO
\set QUIET 1

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager off

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP true


BEGIN;
-- Load the TAP functions.
\i tests/sql/pgtap.sql

-- Load the test data.
\i tests/sql/seed.sql

SET search_path = 'pgtap';

-- Plan the tests.
SELECT plan(12);

-- Run the tests.
SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('', 'transactions', '', '1 month')$$
  , '42P01'
  , 'table ""."transactions" does not exist'
  , 'fail on empty parent table schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', '', '', '1 month')$$
  , '42P01'
  , 'table "public"."" does not exist'
  , 'fail on empty parent table name'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('', '', '', '1 month')$$
  , '42P01'
  , 'table ""."" does not exist'
  , 'fail on empty parent table schema and name'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions (NULL, 'transactions', '', '1 month')$$
  , '42P01'
  , 'table "<NULL>"."transactions" does not exist'
  , 'fail on null parent table schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', NULL, '', '1 month')$$
  , '42P01'
  , 'table "public"."<NULL>" does not exist'
  , 'fail on null parent table name'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions (NULL, NULL, '', '1 month')$$
  , '42P01'
  , 'table "<NULL>"."<NULL>" does not exist'
  , 'fail on empty parent table schema and name'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'charges_template', NULL, '1 month')$$
  , '42P01'
  , 'table "public"."charges_template" is not partitioned'
  , 'fail on non partitioned table'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'users', NULL, '1 month')$$
  , '0A000'
  , '"LIST" partitioning is not supported'
  , 'fail on unsupported partitioning strategy'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'scheduled_entries', NULL, '1 month')$$
  , '0A000'
  , 'multi column partitioned tables are not supported'
  , 'fail on multi column partitioneing'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'orders', NULL, '1 month')$$
  , '0A000'
  , 'partitioning on data type "uuid" is not supported'
  , 'fail on unsupported data type'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '', '1 month')$$
  , '22023'
  , 'name template is required'
  , 'fail on empty name template'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', NULL, '1 month')$$
  , '22023'
  , 'name template is required'
  , 'fail on null name template'
);

-- Finish the tests and clean up.
SELECT * FROM finish(true);

ROLLBACK;
-- run the test psql -d try -Xf test.sql
