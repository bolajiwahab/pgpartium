BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, pg_catalog, public;

SELECT plan(9);

--- We are using mocked now() - '2025-03-01 00:00:00+00'

PREPARE empty_result_with_defaults AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
);

SELECT is_empty(
    'empty_result_with_defaults'
  , 'expire partitions with defaults should return empty result'
);

PREPARE empty_result_with_disable_retention AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>NULL
);

SELECT is_empty(
    'empty_result_with_disable_retention'
  , 'expire partitions with disabled retention should return empty result'
);

PREPARE result_with_retention AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
);

PREPARE expected_with_retention AS VALUES (
$$DROP TABLE test.test__notifications__2024_12;

DROP TABLE test.notifications_2025_01;
$$);

SELECT results_eq(
    'result_with_retention'
  , 'expected_with_retention'
  , 'expire partitions with retention'
);

PREPARE result_with_retention_detach AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
);

PREPARE expected_with_retention_detach AS VALUES (
$$ALTER TABLE test.notifications
    DETACH PARTITION test.test__notifications__2024_12;

DROP TABLE test.test__notifications__2024_12;

ALTER TABLE test.notifications
    DETACH PARTITION test.notifications_2025_01;

DROP TABLE test.notifications_2025_01;
$$);

SELECT results_eq(
    'result_with_retention_detach'
  , 'expected_with_retention_detach'
  , 'expire partitions with detach first'
);

PREPARE result_with_retention_detach_concurrent AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_concurrently=>true
);

PREPARE expected_with_retention_detach_concurrent AS VALUES (
$$ALTER TABLE test.notifications
    DETACH PARTITION test.test__notifications__2024_12 CONCURRENTLY;

DROP TABLE test.test__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_retention_detach'
  , 'expected_with_retention_detach'
  , 'expire partitions with detach first concurrently'
);

PREPARE result_with_retention_detach_only AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_only=>true
);

PREPARE expected_with_retention_detach_only AS VALUES (
$$ALTER TABLE test.notifications
    DETACH PARTITION test.test__notifications__2024_12;

ALTER TABLE test.notifications
    DETACH PARTITION test.notifications_2025_01;
$$);

SELECT results_eq(
    'result_with_retention_detach_only'
  , 'expected_with_retention_detach_only'
  , 'expire partitions with detach only'
);

PREPARE result_with_retention_detach_only_concurrently AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_detach_first=>true
  , p_detach_only=>true
  , p_detach_concurrently=>true
);

PREPARE expected_with_retention_detach_only_concurrently AS VALUES (
$$ALTER TABLE test.notifications
    DETACH PARTITION test.test__notifications__2024_12 CONCURRENTLY;

ALTER TABLE test.notifications
    DETACH PARTITION test.notifications_2025_01 CONCURRENTLY;
$$);

SELECT results_eq(
    'result_with_retention_detach_only_concurrently'
  , 'expected_with_retention_detach_only_concurrently'
  , 'expire partitions with detach only concurrently'
);

PREPARE result_with_timezone_range_date AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'notifications'
  , p_retention=>'1 month'
  , p_timezone=>'Europe/Berlin'
);

PREPARE expected_with_timezone_range_date AS VALUES (
$$DROP TABLE test.test__notifications__2024_12;
$$);

SELECT results_eq(
    'result_with_timezone_range_date'
  , 'expected_with_timezone_range_date'
  , 'expire partitions with timezone range date'
);

PREPARE result_with_timezone_range_timestamp AS
SELECT * FROM pgpartium.expire_partitions (
    p_table_schema=>'test'
  , p_table_name=>'messages'
  , p_retention=>'1 month'
  , p_timezone=>'Europe/Berlin'
);

PREPARE expected_with_timezone_range_timestamp AS VALUES (
$$DROP TABLE test.test__messages__2024_12;

DROP TABLE test.test__messages__2025_01;
$$);

SELECT results_eq(
    'result_with_timezone_range_timestamp'
  , 'expected_with_timezone_range_timestamp'
  , 'expire partitions with timezone range timestamp'
);

SELECT * FROM finish();

ROLLBACK;
