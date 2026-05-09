BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, pg_catalog, public;

SELECT plan(28);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>''
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table ""."transactions" does not exist'
  , 'fail on empty parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>''
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "test"."" does not exist'
  , 'fail on empty parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>''
      , p_table_name=>''
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table ""."" does not exist'
  , 'fail on empty parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>NULL
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "<NULL>"."transactions" does not exist'
  , 'fail on null parent table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>NULL
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "test"."<NULL>" does not exist'
  , 'fail on null parent table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>NULL
      , p_table_name=>NULL
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "<NULL>"."<NULL>" does not exist'
  , 'fail on null parent table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'users'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , '"LIST" partitioning is not supported'
  , 'fail on unsupported partitioning strategy'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'scheduled_entries'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , 'multi column partitioned tables are not supported'
  , 'fail on multi column partitioning'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'books'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '0A000'
  , 'partitioning on data type "text" is not supported'
  , 'fail on unsupported data type'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_schema=>''
    )$$
  , '3F000'
  , 'partition schema "" does not exist'
  , 'fail on empty partition schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_schema=>'nonexistent'
    )$$
  , '3F000'
  , 'partition schema "nonexistent" does not exist'
  , 'fail on non existent partition schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_tablespace=>NULL
    )$$
  , '42704'
  , 'partition tablespace "<NULL>" does not exist'
  , 'fail on null partition tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_index_tablespace=>'nonexistent'
    )$$
  , '42704'
  , 'index tablespace "nonexistent" does not exist'
  , 'fail on non existent index tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_index_tablespace=>NULL
    )$$
  , '42704'
  , 'index tablespace "<NULL>" does not exist'
  , 'fail on null index tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_partition_tablespace=>'nonexistent'
    )$$
  , '42704'
  , 'partition tablespace "nonexistent" does not exist'
  , 'fail on non existent partition tablespace'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>''
      , p_template_table_name=>'charges_template'
    )$$
  , '42P01'
  , 'template table ""."charges_template" does not exist'
  , 'fail on empty template table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'test'
      , p_template_table_name=>''
    )$$
  , '42P01'
  , 'template table "test"."" does not exist'
  , 'fail on empty template table name'
);

SELECT lives_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>''
      , p_template_table_name=>''
    )$$
  , 'pass on empty template table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>NULL
      , p_template_table_name=>'charges_template'
    )$$
  , '42P01'
  , 'template table "<NULL>"."charges_template" does not exist'
  , 'fail on null template table schema'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'test'
      , p_template_table_name=>NULL
    )$$
  , '42P01'
  , 'template table "test"."<NULL>" does not exist'
  , 'fail on null template table name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>'test'
      , p_template_table_name=>'nonexistent'
    )$$
  , '42P01'
  , 'template table "test"."nonexistent" does not exist'
  , 'fail on non existent template table'
);

SELECT lives_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_template_table_schema=>NULL
      , p_template_table_name=>NULL
    )$$
  , 'pass on null template table schema and name'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>''
      , p_interval=>'1 month'
    )$$
  , '22023'
  , 'partition name template is required'
  , 'fail on empty name template'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>NULL
      , p_interval=>'1 month'
    )$$
  , '22023'
  , 'partition name template is required'
  , 'fail on null name template'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_create_default=>true
      , p_default_partition_name_template=>''
    )$$
  , '22023'
  , 'creating default partition requires default partition name template'
  , 'fail on empty default partition name template when creating default partition'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
      , p_create_default=>true
      , p_default_partition_name_template=>NULL)$$
  , '22023'
  , 'creating default partition requires default partition name template'
  , 'fail on null default partition name template when creating default partition'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'transactions'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'0 month'
    )$$
  , '22023'
  , 'interval must not be zero'
  , 'fail on zero interval'
);

SELECT throws_ok($$
    SELECT * FROM pgpartium.make_partitions (
        p_table_schema=>'test'
      , p_table_name=>'accounts'
      , p_partition_name_template=>'{table_schema}__{table_name}__YYYY_MM'
      , p_interval=>'1 month'
    )$$
  , '42P01'
  , 'table "test"."accounts" is not partitioned'
  , 'fail on non partitioned table'
);

SELECT * FROM finish();

ROLLBACK;
