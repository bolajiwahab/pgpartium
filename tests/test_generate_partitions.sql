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

SET search_path TO mock, public, pg_catalog;

-- Plan the tests.
SELECT plan(43);

-- Run the tests.
-- Group: Exceptions
SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>''
      , p_table_name=>'transactions'
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table ""."transactions" does not exist'
  , 'fail on empty parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>''
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "public"."" does not exist'
  , 'fail on empty parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>''
      , p_table_name=>''
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table ""."" does not exist'
  , 'fail on empty parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>NULL
      , p_table_name=>'transactions'
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "<NULL>"."transactions" does not exist'
  , 'fail on null parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>NULL
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "public"."<NULL>" does not exist'
  , 'fail on null parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>NULL
      , p_table_name=>NULL
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "<NULL>"."<NULL>" does not exist'
  , 'fail on null parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'accounts'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "public"."accounts" is not partitioned'
  , 'fail on non partitioned table'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'users'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , '"LIST" partitioning is not supported'
  , 'fail on unsupported partitioning strategy'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'scheduled_entries'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , 'multi column partitioned tables are not supported'
  , 'fail on multi column partitioneing'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'orders'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , 'partitioning on data type "uuid" is not supported'
  , 'fail on unsupported data type'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_schema=>''
    )$$
  , '3F000'
  , 'partition schema "" does not exist'
  , 'fail on empty partition schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_schema=>'nonexistent'
    )$$
  , '3F000'
  , 'partition schema "nonexistent" does not exist'
  , 'fail on non existent partition schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_tablespace=>NULL
    )$$
  , '42704'
  , 'partition tablespace "<NULL>" does not exist'
  , 'fail on null partition tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_tablespace=>'nonexistent'
    )$$
  , '42704'
  , 'partition tablespace "nonexistent" does not exist'
  , 'fail on non existent partition tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>''
      , p_template_table_name=>'charges_template'
    )$$
  , '42P01'
  , 'template table ""."charges_template" does not exist'
  , 'fail on empty template table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'public'
      , p_template_table_name=>''
    )$$
  , '42P01'
  , 'template table "public"."" does not exist'
  , 'fail on empty template table name'
);

SELECT lives_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>''
      , p_template_table_name=>''
    )$$
  , 'pass on empty template table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>NULL
      , p_template_table_name=>'charges_template'
    )$$
  , '42P01'
  , 'template table "<NULL>"."charges_template" does not exist'
  , 'fail on null template table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'public'
      , p_template_table_name=>NULL
    )$$
  , '42P01'
  , 'template table "public"."<NULL>" does not exist'
  , 'fail on null template table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'public'
      , p_template_table_name=>'nonexistent'
    )$$
  , '42P01'
  , 'template table "public"."nonexistent" does not exist'
  , 'fail on non existent template table'
);

SELECT lives_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>NULL
      , p_template_table_name=>NULL
    )$$
  , 'pass on null template table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '22023'
  , 'name template is required'
  , 'fail on empty name template'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '22023'
  , 'name template is required'
  , 'fail on null name template'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_create_default=>true
      , p_default_partition_name_template=>''
    )$$
  , '22023'
  , 'creating default partition requires default partition name template'
  , 'fail on empty default partition name template when creating default partition'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.generate_partitions (
        p_table_schema=>'public'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
      , p_interval=>'1 month'
      , p_create_default=>true
      , p_default_partition_name_template=>NULL)$$
  , '22023'
  , 'creating default partition requires default partition name template'
  , 'fail on null default partition name template when creating default partition'
);

-- Group: Outputs
PREPARE result_with_defaults AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_defaults AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_defaults'
  , 'expected_with_defaults'
  , 'generate partitions with defaults'
);

PREPARE result_with_past AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_past=>1
);

PREPARE expected_with_past AS VALUES (
$$CREATE TABLE public.public__transactions__2025_02
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');

CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_past'
  , 'expected_with_past'
  , 'generate partitions with past'
);

PREPARE result_with_future AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
);

PREPARE expected_with_future AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE public.public__transactions__2025_04
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_future'
  , 'expected_with_future'
  , 'generate partitions with future'
);

PREPARE result_with_create_default AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_create_default=>true
  , p_default_partition_name_template=>'{schema}__{table}__default'
);

PREPARE expected_with_create_default AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE public.public__transactions__default
    PARTITION OF public.transactions
    DEFAULT;
$$);

SELECT results_eq(
    'result_with_create_default'
  , 'expected_with_create_default'
  , 'generate partitions with create default'
);

PREPARE result_with_partition_schema AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_schema=>'partitions'
);

PREPARE expected_with_partition_schema AS VALUES (
$$CREATE TABLE partitions.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_partition_schema'
  , 'expected_with_partition_schema'
  , 'generate partitions with partition schema'
);

PREPARE result_with_partition_tablespace AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_tablespace=>'pgpartium'
);

PREPARE expected_with_partition_tablespace AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00')
TABLESPACE pgpartium;
$$);

SELECT results_eq(
    'result_with_partition_tablespace'
  , 'expected_with_partition_tablespace'
  , 'generate partitions with partition tablespace'
);

PREPARE result_with_partition_storage_parameters AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_storage_parameters=>'{"fillfactor": "90"}'
);

PREPARE expected_with_partition_storage_parameters AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00')
WITH (fillfactor = '90');
$$);

SELECT results_eq(
    'result_with_partition_storage_parameters'
  , 'expected_with_partition_storage_parameters'
  , 'generate partitions with partition storage parameters'
);

PREPARE result_with_template_table AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'public'
  , p_template_table_name=>'transactions_template'
);

PREPARE expected_with_template_table AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE INDEX public__transactions__2025_03_account_id_idx
    ON public.public__transactions__2025_03
 USING btree (account_id);

CREATE INDEX public__transactions__2025_03_status_active_idx
    ON public.public__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;
$$);

SELECT results_eq(
    'result_with_template_table'
  , 'expected_with_template_table'
  , 'generate partitions with template table'
);

PREPARE result_with_template_table_and_index_tablespace AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'public'
  , p_template_table_name=>'transactions_template'
  , p_index_tablespace=>'pgpartium'
);

PREPARE expected_with_template_table_and_index_tablespace AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE INDEX public__transactions__2025_03_account_id_idx
    ON public.public__transactions__2025_03
 USING btree (account_id)
TABLESPACE pgpartium;

CREATE INDEX public__transactions__2025_03_status_active_idx
    ON public.public__transactions__2025_03
 USING btree (status)
TABLESPACE pgpartium
 WHERE status = 'active'::text;
$$);

SELECT results_eq(
    'result_with_template_table_and_index_tablespace'
  , 'expected_with_template_table_and_index_tablespace'
  , 'generate partitions with template table and index tablespace'
);

PREPARE result_with_template_table_and_index_storage_parameters AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'public'
  , p_template_table_name=>'transactions_template'
  , p_index_storage_parameters=>'{"fillfactor": "90"}'
);

PREPARE expected_with_template_table_and_index_storage_parameters AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE INDEX public__transactions__2025_03_account_id_idx
    ON public.public__transactions__2025_03
 USING btree (account_id);

CREATE INDEX public__transactions__2025_03_status_active_idx
    ON public.public__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;
$$);

SELECT results_eq(
    'result_with_template_table_and_index_storage_parameters'
  , 'expected_with_template_table_and_index_storage_parameters'
  , 'generate partitions with template table and index storage parameters'
);

PREPARE result_with_retention AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_retention=>'-1 month'
  , p_past=>1
);

PREPARE expected_with_retention AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_retention'
  , 'expected_with_retention'
  , 'generate partitions skipping partitions that would be expired by retention'
);

PREPARE result_with_timezone AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_timezone=>'Europe/Berlin'
);

PREPARE expected_with_timezone AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+01') TO ('2025-04-01 00:00:00+02');
$$);

SELECT results_eq(
    'result_with_timezone'
  , 'expected_with_timezone'
  , 'generate partitions with timezone'
);

-- Overlapping partitions: START
CREATE TABLE public.public__transactions__2025_03_01
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-03-02 00:00:00+00');

PREPARE result_with_not_skip_overlapping AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
);

PREPARE expected_with_not_skip_overlapping AS VALUES (
$$CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE public.public__transactions__2025_04
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_not_skip_overlapping'
  , 'expected_with_not_skip_overlapping'
  , 'generate partitions not skipping overlapping partitions'
);

PREPARE result_with_skip_overlapping AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
  , p_skip_overlapping=>true
);

PREPARE expected_with_skip_overlapping AS VALUES (
$$CREATE TABLE public.public__transactions__2025_04
    PARTITION OF public.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_skip_overlapping'
  , 'expected_with_skip_overlapping'
  , 'generate partitions skipping overlapping partitions'
);
-- Overlapping partitions: END

PREPARE result_with_latest_partition_as_start_time AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'notifications'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_latest_partition_as_start_time AS VALUES (
$$CREATE TABLE public.public__notifications__2025_02
    PARTITION OF public.notifications
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE public.public__notifications__2025_03
    PARTITION OF public.notifications
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
$$);

SELECT results_eq(
    'result_with_latest_partition_as_start_time'
  , 'expected_with_latest_partition_as_start_time'
  , 'generate partitions with latest partition as start time'
);

PREPARE result_with_partition_by_timestamp AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'charges'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_partition_by_timestamp AS VALUES (
$$CREATE TABLE public.public__charges__2025_03
    PARTITION OF public.charges
    FOR VALUES FROM ('2025-03-01 00:00:00') TO ('2025-04-01 00:00:00');
$$);

SELECT results_eq(
    'result_with_partition_by_timestamp'
  , 'expected_with_partition_by_timestamp'
  , 'generate partitions with partition by timestamp'
);

PREPARE result_with_epoch_integer AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'sales'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_epoch_integer AS VALUES (
$$CREATE TABLE public.public__sales__2025_03
    PARTITION OF public.sales
    FOR VALUES FROM ('1740787200') TO ('1743465600');
$$);

SELECT results_eq(
    'result_with_epoch_integer'
  , 'expected_with_epoch_integer'
  , 'generate partitions with epoch integer'
);

PREPARE result_with_epoch_bigint AS
SELECT * FROM pgpartium.generate_partitions (
    p_table_schema=>'public'
  , p_table_name=>'trips'
  , p_partition_name_template=>'{schema}__{table}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_epoch_bigint AS VALUES (
$$CREATE TABLE public.public__trips__2025_03
    PARTITION OF public.trips
    FOR VALUES FROM ('1740787200000') TO ('1743465600000');
$$);

SELECT results_eq(
    'result_with_epoch_bigint'
  , 'expected_with_epoch_bigint'
  , 'generate partitions with epoch bigint'
);

-- Finish the tests and clean up.
SELECT * FROM finish(true);

ROLLBACK;
