BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, pg_catalog, public;

SELECT plan(7);

CREATE SCHEMA test;

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
        p_table_schema=>'test'
      , p_table_name=>''
    )$$
  , '42P01'
  , 'table "test"."" does not exist'
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
        p_table_schema=>'test'
      , p_table_name=>NULL
    )$$
  , '42P01'
  , 'table "test"."<NULL>" does not exist'
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

-- Non partitioned table.
CREATE TABLE test.accounts (
    user_id uuid NOT NULL
  , charge_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT accounts_pkey PRIMARY KEY (user_id, created_at)
  , CONSTRAINT accounts_charge_id_key UNIQUE (charge_id)
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.expire_partitions (
        p_table_schema=>'test'
      , p_table_name=>'accounts'
    )$$
  , '42P01'
  , 'table "test"."accounts" is not partitioned'
  , 'fail on non partitioned table'
);

SELECT * FROM finish();

ROLLBACK;
