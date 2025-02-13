-- does table exists
-- is table partitioned
-- is it partitioned on range?
-- is partitioned on one column only
-- is the data type int/date/timestamp
-- 


-- how to manage disable triggers on template
-- table options on template

CREATE OR REPLACE FUNCTION pgpartium.generate_partitions (table_schema text, table_name text)
RETURNS SETOF text
LANGUAGE plpgsql
SET timezone TO 'utc'
AS $BODY$
DECLARE
    _table_exists boolean;
    _is_table_partitioned boolean;
    _partitioning_details record;
BEGIN
    _table_exists := pgpartium.table_exists(table_schema, table_name);
    _is_table_partitioned := pgpartium.is_table_partitioned(table_schema, table_name);
    _partitioning_details := pgpartium.get_partitioning_details(table_schema, table_name);
    
    IF NOT _table_exists THEN
        RAISE 'table "%"."%" does not exist', table_schema, table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT _is_table_partitioned THEN
        RAISE 'table "%"."%" is not partitioned', table_schema, table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT _partitioning_details.strategy = 'RANGE' THEN
        RAISE 'table "%"."%" is not partitioned on range', table_schema, table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT _partitioning_details.number_of_keys = 1 THEN
        RAISE 'multi column partitioned tables are not supported'
        USING ERRCODE = 'undefined_table',
                 HINT = 'table ' || '"' || table_schema || '"' || '.' || '"' || table_name || '"' || ' is partitioned on more than one column';
    END IF;

    IF NOT _partitioning_details.keys_data_types IN ('date', 'timestamp with time zone', 'timestamp without time zone', 'integer', 'bigint') THEN
        RAISE 'partitioning on data type "%" is not supported', _partitioning_details.keys_data_types
        USING ERRCODE = 'undefined_table',
               DETAIL = 'table ' || '"' || table_schema || '"' || '.' || '"' || table_name || '"' || ' is partitioned on a data type that is not supported',
                 HINT = 'supported data types are date, timestamp with time zone, timestamp without time zone, integer, and bigint';
        -- RAISE 'table "%"."%" is partitioned on a data type that is not date, timestamp, int, or bigint', table_schema, table_name
        -- USING ERRCODE = 'undefined_table';
    END IF;

END;
$BODY$;
