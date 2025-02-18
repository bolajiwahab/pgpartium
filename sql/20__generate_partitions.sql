-- does table exists
-- is table partitioned
-- is it partitioned on range?
-- is partitioned on one column only
-- is the data type int/date/timestamp
-- we need a retention function, returns list of partition which have passed retention period
-- if null, we return empty sets


-- how to manage disable triggers on template
-- table options on template

CREATE OR REPLACE FUNCTION pgpartium.generate_partitions (table_schema text, table_name text, p_interval interval, past integer, future integer, prefix text, suffix text, timezone text DEFAULT 'UTC')
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$
DECLARE
    partitions record;
    _table_exists boolean;
    _is_table_partitioned boolean;
    _partitioning_details record;
    ddl                       text := '';
    ddl_indexes               text;
    ddl_constraints           text;
    ddl_triggers              text;
BEGIN

    PERFORM set_config('timezone', timezone, true);

    _table_exists := pgpartium.table_exists(table_schema, table_name);
    _is_table_partitioned := pgpartium.is_table_partitioned(table_schema, table_name);
    _partitioning_details := pgpartium.get_partitioning_details(table_schema, table_name);

  CREATE TEMPORARY TABLE current_bounds ON COMMIT DROP AS
SELECT case _partitioning_details.keys_data_types 
when 'timestamp with time zone' then matches[1]::timestamptz 
when 'timestamp without time zone' then matches[1]::timestamptz
when 'date' then matches[1]::date
when 'integer' then to_timestamp(matches[1]::integer)
when 'bigint' then to_timestamp(matches[1]::bigint / 1000)
end as lowerbound,
case _partitioning_details.keys_data_types 
when 'timestamp with time zone' then matches[2]::timestamptz
when 'timestamp without time zone' then matches[2]::timestamptz
when 'date' then matches[2]::date
when 'integer' then to_timestamp(matches[2]::integer)
when 'bigint' then to_timestamp(matches[2]::bigint / 1000)
end as upperbound
FROM pg_catalog.pg_inherits       AS i
INNER JOIN pg_catalog.pg_class     AS p  ON i.inhparent = p.oid
INNER JOIN pg_catalog.pg_class     AS c  ON i.inhrelid = c.oid
INNER JOIN pg_catalog.pg_namespace AS pn ON pn.oid = p.relnamespace
INNER JOIN pg_catalog.pg_namespace AS cn ON cn.oid = c.relnamespace
CROSS JOIN regexp_matches(pg_get_expr(c.relpartbound, c.oid), $bound$\(\'?(.+?)\'?\).+\(\'?(.+?)\'?\)$bound$) AS matches
WHERE c.relispartition
  AND c.relkind = 'r'
  AND p.relname = table_name
  AND pn.nspname = table_schema;

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
    END IF;

    FOR partitions IN
        WITH dateset AS (
            SELECT "date"
            FROM generate_series(date_trunc('month', 'today'::date) - (p_interval * past), 'today'::date + (p_interval * future), p_interval) AS "date"
        ),
        daterange AS (
            -- generate partition bounds
            SELECT to_char("date", suffix) AS part_suffix,
                    "date" AS exclusive_start_time,
                "date" + p_interval AS exclusive_end_time
        FROM dateset
        )
        SELECT
            table_name || part_suffix as partition_name,
            exclusive_start_time,
            exclusive_end_time
        FROM daterange
    LOOP
        IF NOT EXISTS (SELECT 1 FROM current_bounds WHERE current_bounds.lowerbound = partitions.exclusive_start_time AND current_bounds.upperbound = partitions.exclusive_end_time) THEN
            RAISE NOTICE 'partition "%", "%", "%"', partitions.partition_name, partitions.exclusive_start_time, partitions.exclusive_end_time;
        END IF;
    END LOOP;

END;
$BODY$;
