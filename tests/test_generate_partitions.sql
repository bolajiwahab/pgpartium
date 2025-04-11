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

SET search_path TO pgtap, mock, public, pg_catalog;

-- Plan the tests.
SELECT plan(21);

-- Run the tests.
-- Group: Exceptions
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

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_partition_schema=>'')$$
  , '3F000'
  , 'partition schema "" does not exist'
  , 'fail on empty partition schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_partition_schema=>'nonexistent')$$
  , '3F000'
  , 'partition schema "nonexistent" does not exist'
  , 'fail on non existent partition schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>'', p_template_table_name=>'charges_template')$$
  , '42P01'
  , 'template table ""."charges_template" does not exist'
  , 'fail on empty template table schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>'public', p_template_table_name=>'')$$
  , '42P01'
  , 'template table "public"."" does not exist'
  , 'fail on empty template table name'
);

SELECT lives_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>'', p_template_table_name=>'')$$
  , 'pass on empty template table schema and name'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>NULL, p_template_table_name=>'charges_template')$$
  , '42P01'
  , 'template table "<NULL>"."charges_template" does not exist'
  , 'fail on null template table schema'
);

SELECT throws_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>'public', p_template_table_name=>NULL)$$
  , '42P01'
  , 'template table "public"."<NULL>" does not exist'
  , 'fail on null template table name'
);

SELECT lives_ok($$SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month', p_template_table_schema=>NULL, p_template_table_name=>NULL)$$
  , 'pass on null template table schema and name'
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

-- Group: Outputs
PREPARE result_with_defaults AS
SELECT * FROM pgpartium.generate_partitions ('public', 'transactions', '{schema}__{table}__YYYY_MM', '1 month');

PREPARE expected_with_defaults
AS VALUES ($$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq('result_with_defaults', 'expected_with_defaults', 'result with defaults');

-- Finish the tests and clean up.
SELECT * FROM finish(true);

ROLLBACK;
