BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, pg_catalog, public;

SELECT plan(24);

-- We are using mocked now() - '2025-03-01 00:00:00'

PREPARE result_with_defaults AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_defaults AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_defaults'
  , 'expected_with_defaults'
  , 'make partitions with defaults'
);

PREPARE result_with_past AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_past=>1
);

PREPARE expected_with_past AS VALUES (
$$CREATE TABLE test.test__transactions__2025_02
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');

CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_past'
  , 'expected_with_past'
  , 'make partitions with past'
);

PREPARE result_with_future AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
);

PREPARE expected_with_future AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_future'
  , 'expected_with_future'
  , 'make partitions with future'
);

PREPARE result_with_create_default AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_create_default=>true
  , p_default_partition_name_template=>'{table_schema}__{table_name}__default'
);

PREPARE expected_with_create_default AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE test.test__transactions__default
    PARTITION OF test.transactions
    DEFAULT;
$$);

SELECT results_eq(
    'result_with_create_default'
  , 'expected_with_create_default'
  , 'make partitions with create default'
);

PREPARE result_with_create_default_with_template AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_create_default=>true
  , p_default_partition_name_template=>'{table_schema}__{table_name}__default'
  , p_template_table_schema=>'test'
  , p_template_table_name=>'transactions_template'
);

PREPARE expected_with_create_default_with_template AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX test__transactions__2025_03_status_active_key
    ON test.test__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX test__transactions__2025_03_account_id_idx
    ON test.test__transactions__2025_03
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE test.test__transactions__default
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__default_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__default_user_id_key UNIQUE (user_id)
    )
    DEFAULT;

CREATE UNIQUE INDEX test__transactions__default_status_active_key
    ON test.test__transactions__default
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX test__transactions__default_account_id_idx
    ON test.test__transactions__default
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__default
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__default
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__default
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
$$);

SELECT results_eq(
    'result_with_create_default_with_template'
  , 'expected_with_create_default_with_template'
  , 'make partitions with create default with template'
);

PREPARE result_with_partition_schema AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_schema=>'partitions'
);

PREPARE expected_with_partition_schema AS VALUES (
$$CREATE TABLE partitions.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_partition_schema'
  , 'expected_with_partition_schema'
  , 'make partitions with partition schema'
);

PREPARE result_with_partition_tablespace AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_tablespace=>'pgpartium'
);

PREPARE expected_with_partition_tablespace AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00')
TABLESPACE pgpartium;
$$);

SELECT results_eq(
    'result_with_partition_tablespace'
  , 'expected_with_partition_tablespace'
  , 'make partitions with partition tablespace'
);

PREPARE result_with_partition_storage_parameters AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_partition_storage_parameters=>'{"fillfactor": "90"}'
);

PREPARE expected_with_partition_storage_parameters AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00')
WITH (fillfactor = '90');
$$);

SELECT results_eq(
    'result_with_partition_storage_parameters'
  , 'expected_with_partition_storage_parameters'
  , 'make partitions with partition storage parameters'
);

PREPARE result_with_template_table AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'test'
  , p_template_table_name=>'transactions_template'
);

PREPARE expected_with_template_table AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX test__transactions__2025_03_status_active_key
    ON test.test__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX test__transactions__2025_03_account_id_idx
    ON test.test__transactions__2025_03
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
$$);

SELECT results_eq(
    'result_with_template_table'
  , 'expected_with_template_table'
  , 'make partitions with template table'
);

PREPARE result_with_template_table_and_index_tablespace AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'test'
  , p_template_table_name=>'transactions_template'
  , p_index_tablespace=>'pgpartium'
);

PREPARE expected_with_template_table_and_index_tablespace AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX test__transactions__2025_03_status_active_key
    ON test.test__transactions__2025_03
 USING btree (status)
TABLESPACE pgpartium
 WHERE status = 'active'::text;

CREATE INDEX test__transactions__2025_03_account_id_idx
    ON test.test__transactions__2025_03
 USING btree (account_id)
TABLESPACE pgpartium;

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
$$);

SELECT results_eq(
    'result_with_template_table_and_index_tablespace'
  , 'expected_with_template_table_and_index_tablespace'
  , 'make partitions with template table and index tablespace'
);

PREPARE result_with_retention AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_retention=>'1 month'
  , p_past=>2
);

PREPARE expected_with_retention AS VALUES (
$$CREATE TABLE test.test__transactions__2025_02
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');

CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_retention'
  , 'expected_with_retention'
  , 'make partitions skipping partitions that would be expired by retention'
);

PREPARE result_with_timezone AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_timezone=>'Europe/Berlin'
);

PREPARE expected_with_timezone AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+01') TO ('2025-04-01 00:00:00+02');
$$);

SELECT results_eq(
    'result_with_timezone'
  , 'expected_with_timezone'
  , 'make partitions with timezone'
);

PREPARE result_with_idempotent_ddl AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_idempotent_ddl=>true
);

PREPARE expected_with_idempotent_ddl AS VALUES (
$$CREATE TABLE IF NOT EXISTS test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_idempotent_ddl'
  , 'expected_with_idempotent_ddl'
  , 'make partitions if not exists'
);

PREPARE result_with_default_partition_idempotent_ddl AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_default_partition_name_template=>'{table_schema}__{table_name}__default'
  , p_create_default=>true
  , p_interval=>'1 month'
  , p_idempotent_ddl=>true
);

PREPARE expected_with_default_partition_idempotent_ddl AS VALUES (
$$CREATE TABLE IF NOT EXISTS test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE IF NOT EXISTS test.test__transactions__default
    PARTITION OF test.transactions
    DEFAULT;
$$);

SELECT results_eq(
    'result_with_default_partition_idempotent_ddl'
  , 'expected_with_default_partition_idempotent_ddl'
  , 'make partitions with default partition if not exists'
);

PREPARE result_with_template_with_idempotent_ddl AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_template_table_schema=>'test'
  , p_template_table_name=>'transactions_template'
  , p_idempotent_ddl=>true
);

PREPARE expected_with_template_with_idempotent_ddl AS VALUES (
$$CREATE TABLE IF NOT EXISTS test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX IF NOT EXISTS test__transactions__2025_03_status_active_key
    ON test.test__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX IF NOT EXISTS test__transactions__2025_03_account_id_idx
    ON test.test__transactions__2025_03
 USING btree (account_id);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
$$);

SELECT results_eq(
    'result_with_template_with_idempotent_ddl'
  , 'expected_with_template_with_idempotent_ddl'
  , 'make partitions with template with if not exists'
);

PREPARE result_with_create_default_with_template_with_idempotent_ddl AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_create_default=>true
  , p_default_partition_name_template=>'{table_schema}__{table_name}__default'
  , p_template_table_schema=>'test'
  , p_template_table_name=>'transactions_template'
  , p_idempotent_ddl=>true
);

PREPARE expected_with_create_default_with_template_with_idempotent_ddl AS VALUES (
$$CREATE TABLE IF NOT EXISTS test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX IF NOT EXISTS test__transactions__2025_03_status_active_key
    ON test.test__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX IF NOT EXISTS test__transactions__2025_03_account_id_idx
    ON test.test__transactions__2025_03
 USING btree (account_id);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE IF NOT EXISTS test.test__transactions__default
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__default_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__default_user_id_key UNIQUE (user_id)
    )
    DEFAULT;

CREATE UNIQUE INDEX IF NOT EXISTS test__transactions__default_status_active_key
    ON test.test__transactions__default
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX IF NOT EXISTS test__transactions__default_account_id_idx
    ON test.test__transactions__default
 USING btree (account_id);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__default
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__default
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__default
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
$$);

SELECT results_eq(
    'result_with_create_default_with_template_with_idempotent_ddl'
  , 'expected_with_create_default_with_template_with_idempotent_ddl'
  , 'make partitions with create default with template with if not exists'
);

--- Overlapping partitions: START
CREATE TABLE test.test__transactions__2025_03_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-03-02 00:00:00+00');

PREPARE result_with_not_skip_overlapping AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
);

PREPARE expected_with_not_skip_overlapping AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_not_skip_overlapping'
  , 'expected_with_not_skip_overlapping'
  , 'make partitions not skipping overlapping partitions'
);

PREPARE result_with_skip_overlapping AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_future=>1
  , p_skip_overlapping=>true
);

PREPARE expected_with_skip_overlapping AS VALUES (
$$CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_skip_overlapping'
  , 'expected_with_skip_overlapping'
  , 'make partitions skipping overlapping partitions'
);

DROP TABLE test.test__transactions__2025_03_01;
--- Overlapping partitions: END

--- existing_past_partitions: START
CREATE TABLE test.test__transactions__2025_02
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');

PREPARE result_with_existing_past_partitions AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
  , p_past=>1
);

PREPARE expected_with_existing_past_partitions AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_existing_past_partitions'
  , 'expected_with_existing_past_partitions'
  , 'make partitions with existing past partitions'
);

DROP TABLE test.test__transactions__2025_02;
--- existing_past_partitions: END

--- latest_partition_as_start_time: START
CREATE TABLE test.test__transactions__2025_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-02-01 00:00:00+00');

PREPARE result_with_latest_partition_as_start_time AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
  , p_interval=>'1 month'
);

PREPARE expected_with_latest_partition_as_start_time AS VALUES (
$$CREATE TABLE test.test__transactions__2025_02
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-02-01 00:00:00+00') TO ('2025-03-01 00:00:00+00');

CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_latest_partition_as_start_time'
  , 'expected_with_latest_partition_as_start_time'
  , 'make partitions with latest partition as start time'
);

DROP TABLE test.test__transactions__2025_01;
--- latest_partition_as_start_time: END

PREPARE result_with_hourly_interval AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM_DD_HH24'
  , p_interval=>'1 hour'
);

PREPARE expected_with_hourly_interval AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03_01_00
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-03-01 01:00:00+00');
$$);

SELECT results_eq(
    'result_with_hourly_interval'
  , 'expected_with_hourly_interval'
  , 'make partitions with hourly interval'
);

PREPARE result_with_daily_interval AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM_DD'
  , p_interval=>'1 day'
);

PREPARE expected_with_daily_interval AS VALUES (
$$CREATE TABLE test.test__transactions__2025_03_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-03-02 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_daily_interval'
  , 'expected_with_daily_interval'
  , 'make partitions with daily interval'
);

PREPARE result_with_weekly_interval AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY"w"WW'
  , p_interval=>'1 week'
);

PREPARE expected_with_weekly_interval AS VALUES (
$$CREATE TABLE test.test__transactions__2025w08
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-02-24 00:00:00+00') TO ('2025-03-03 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_weekly_interval'
  , 'expected_with_weekly_interval'
  , 'make partitions with weekly interval'
);

PREPARE result_with_yearly_interval AS
SELECT * FROM pgpartium.make_partitions (
    p_table_schema=>'test'
  , p_table_name=>'transactions'
  , p_partition_name_template=>'{table_schema}__{table_name}__YYYY'
  , p_interval=>'1 year'
);

PREPARE expected_with_yearly_interval AS VALUES (
$$CREATE TABLE test.test__transactions__2025
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');
$$);

SELECT results_eq(
    'result_with_yearly_interval'
  , 'expected_with_yearly_interval'
  , 'make partitions with yearly interval'
);

SELECT * FROM finish();

ROLLBACK;
