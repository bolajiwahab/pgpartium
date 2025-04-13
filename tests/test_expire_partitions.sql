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

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, public, pg_catalog;

-- Plan the tests.
SELECT plan(15);

-- Run the tests.
-- Group: Exceptions
SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>''
      , p_table_name=>'transactions'
    )$$
  , '42P01'
  , 'table ""."transactions" does not exist'
  , 'fail on empty parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>'public'
      , p_table_name=>''
    )$$
  , '42P01'
  , 'table "public"."" does not exist'
  , 'fail on empty parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>''
      , p_table_name=>''
    )$$
  , '42P01'
  , 'table ""."" does not exist'
  , 'fail on empty parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>NULL
      , p_table_name=>'transactions'
    )$$
  , '42P01'
  , 'table "<NULL>"."transactions" does not exist'
  , 'fail on null parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>'public'
      , p_table_name=>NULL
    )$$
  , '42P01'
  , 'table "public"."<NULL>" does not exist'
  , 'fail on null parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>NULL
      , p_table_name=>NULL
    )$$
  , '42P01'
  , 'table "<NULL>"."<NULL>" does not exist'
  , 'fail on null parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>'public'
      , p_table_name=>'accounts'
    )$$
  , '42P01'
  , 'table "public"."accounts" is not partitioned'
  , 'fail on non partitioned table'
);

-- Group: Outputs
PREPARE empty_result_with_defaults AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
);

SELECT is_empty(
    'empty_result_with_defaults'
  , 'expire partitions with defaults should return empty result'
);

PREPARE empty_result_with_disable_retention AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'-1'
);

SELECT is_empty(
    'empty_result_with_disable_retention'
  , 'expire partitions with disable p_retention should return empty result'
);

-- Add more partitions for retention.
-- We are using mocked now() from tests/resources/mock.sql.
CREATE TABLE public.public__notifications__2024_12
    PARTITION OF public.notifications
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE public.public__notifications__2025_02
    PARTITION OF public.notifications
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE public.public__notifications__2025_03
    PARTITION OF public.notifications
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

PREPARE result_with_retention AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
);

PREPARE expected_with_retention AS VALUES (
$$DROP TABLE public.public__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_retention'
  , 'expected_with_retention'
  , 'expire partitions with retention'
);

PREPARE result_with_retention_detach AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
);

PREPARE expected_with_retention_detach AS VALUES (
$$ALTER TABLE public.notifications
    DETACH PARTITION public.public__notifications__2024_12;

DROP TABLE public.public__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_retention_detach'
  , 'expected_with_retention_detach'
  , 'expire partitions with detach first'
);

PREPARE result_with_retention_detach_concurrent AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_concurrently=>true
);

PREPARE expected_with_retention_detach_concurrent AS VALUES (
$$ALTER TABLE public.notifications
    DETACH PARTITION public.public__notifications__2024_12 CONCURRENTLY;

DROP TABLE public.public__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_retention_detach'
  , 'expected_with_retention_detach'
  , 'expire partitions with detach first concurrently'
);

PREPARE result_with_retention_detach_only AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_only=>true
);

PREPARE expected_with_retention_detach_only AS VALUES (
$$ALTER TABLE public.notifications
    DETACH PARTITION public.public__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_retention_detach_only'
  , 'expected_with_retention_detach_only'
  , 'expire partitions with detach only'
);

PREPARE result_with_retention_detach_only_concurrently AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_only=>true
  , p_detach_concurrently=>true
);

PREPARE expected_with_retention_detach_only_concurrently AS VALUES (
$$ALTER TABLE public.notifications
    DETACH PARTITION public.public__notifications__2024_12 CONCURRENTLY;
$$);

SELECT results_eq(
    'result_with_retention_detach_only_concurrently'
  , 'expected_with_retention_detach_only_concurrently'
  , 'expire partitions with detach only concurrently'
);

PREPARE result_with_timezone AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_timezone=>'Europe/Berlin'
);

PREPARE expected_with_timezone AS VALUES (
$$DROP TABLE public.public__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_timezone'
  , 'expected_with_timezone'
  , 'expire partitions with timezone'
);

-- Finish the tests and clean up.
SELECT * FROM finish(true);

ROLLBACK;
