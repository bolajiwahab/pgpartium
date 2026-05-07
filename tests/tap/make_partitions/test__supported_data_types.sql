BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

\i tests/fixtures/schema.sql

SET search_path TO mock, pg_catalog, public;

SELECT plan(6);

-- We are using mocked now() - '2025-03-01 00:00:00'

PREPARE result_with_partition_by_date AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_date'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_date AS VALUES (
$$CREATE TABLE test.test__transactions_by_date__2025_03
    PARTITION OF test.transactions_by_date
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
$$);

SELECT results_eq(
    'result_with_partition_by_date'
  , 'expected_with_partition_by_date'
  , 'make partitions with partition by date'
);

PREPARE result_with_partition_by_timestamptz AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_timestamptz'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_timestamptz AS VALUES (
$$CREATE TABLE test.test__transactions_by_timestamptz__2025_03
    PARTITION OF test.transactions_by_timestamptz
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_partition_by_timestamptz'
  , 'expected_with_partition_by_timestamptz'
  , 'make partitions with partition by timestamptz'
);

PREPARE result_with_partition_by_timestamp AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_timestamp'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_timestamp AS VALUES (
$$CREATE TABLE test.test__transactions_by_timestamp__2025_03
    PARTITION OF test.transactions_by_timestamp
    FOR VALUES FROM ('2025-03-01 00:00:00') TO ('2025-04-01 00:00:00');
$$);

SELECT results_eq(
    'result_with_partition_by_timestamp'
  , 'expected_with_partition_by_timestamp'
  , 'make partitions with partition by timestamp'
);

PREPARE result_with_partition_by_int4 AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_int4'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_int4 AS VALUES (
$$CREATE TABLE test.test__transactions_by_int4__2025_03
    PARTITION OF test.transactions_by_int4
    FOR VALUES FROM ('1740787200') TO ('1743465600');
$$);

SELECT results_eq(
    'result_with_partition_by_int4'
  , 'expected_with_partition_by_int4'
  , 'make partitions with partition by int4'
);

PREPARE result_with_partition_by_int8 AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_int8'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_int8 AS VALUES (
$$CREATE TABLE test.test__transactions_by_int8__2025_03
    PARTITION OF test.transactions_by_int8
    FOR VALUES FROM ('1740787200000') TO ('1743465600000');
$$);

SELECT results_eq(
    'result_with_partition_by_int8'
  , 'expected_with_partition_by_int8'
  , 'make partitions with partition by int8'
);

PREPARE result_with_partition_by_uuidv7 AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions_by_uuidv7'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_uuidv7 AS VALUES (
$$CREATE TABLE test.test__transactions_by_uuidv7__2025_03
    PARTITION OF test.transactions_by_uuidv7
    FOR VALUES FROM ('01954f00-b000-0000-0000-000000000000') TO ('0195eea5-d400-0000-0000-000000000000');
$$);

SELECT results_eq(
    'result_with_partition_by_uuidv7'
  , 'expected_with_partition_by_uuidv7'
  , 'make partitions with partition by uuidv7'
);

SELECT * FROM finish();

ROLLBACK;
