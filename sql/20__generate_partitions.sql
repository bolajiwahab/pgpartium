-- get parent constraint
-- get parent triggers
-- get parent indexes
-- get template constraints
-- get template triggers
-- get template indexes
-- we then sort/merge them, if an index already exist on the parent, we skip it on the child
-- we have to generate conname, indexname, triggername according to the postgresql namning conventions
CREATE OR REPLACE FUNCTION pgpartium.generate_partitions (
    table_schema text
  , table_name text
  , p_interval text
  , past integer
  , future integer
  , prefix text
  , suffix text
  , template_table_schema text = NULL
  , template_table_name text = NULL
  , partition_schema text = 'public'
  , timezone text = 'UTC'
)
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$
DECLARE
    partitions record;
    _table_exists boolean;
    _template_exists boolean;
    _is_table_partitioned boolean;
    _partitioning_details record;
    constraints record;
    ddl                       text := '';
    ddl_indexes               text;
    ddl_constraints           text;
    ddl_triggers              text;
BEGIN

    PERFORM set_config('timezone', timezone, true);

    _table_exists := pgpartium.table_exists(table_schema, table_name);
    _template_exists := pgpartium.table_exists(template_table_schema, template_table_name);
    _is_table_partitioned := pgpartium.is_table_partitioned(table_schema, table_name);
    _partitioning_details := pgpartium.get_partitioning_details(table_schema, table_name);

    CREATE TEMPORARY TABLE current_bounds ON COMMIT DROP AS
    SELECT lowerbound
         , upperbound
      FROM pgpartium.get_partition_bounds(table_schema, table_name, _partitioning_details.keys_data_types);

    IF NOT _table_exists THEN
        RAISE 'table "%"."%" does not exist', table_schema, table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT (num_nulls(template_table_schema, template_table_name) = 2) AND NOT _template_exists THEN
        RAISE 'template table "%"."%" does not exist', template_table_schema, template_table_name
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

    CREATE TEMPORARY TABLE template_constraints ON COMMIT DROP AS
    SELECT constraint_name
         , contype
         , columns
         , constraint_definition
      FROM pgpartium.get_constraints(template_table_schema, template_table_name);

    CREATE TEMPORARY TABLE parent_constraints ON COMMIT DROP AS
    SELECT constraint_name
         , contype
         , columns
         , constraint_definition
      FROM pgpartium.get_constraints(table_schema, table_name);

    CREATE TEMPORARY TABLE partition_constraints ON COMMIT DROP AS
    SELECT template_constraints.constraint_name
         , template_constraints.contype
         , template_constraints.columns
         , template_constraints.constraint_definition
      FROM template_constraints
      LEFT JOIN parent_constraints
        ON template_constraints.constraint_definition = parent_constraints.constraint_definition
     WHERE parent_constraints.constraint_definition IS NULL;

    -- -- Get Constraint definition
    -- SELECT string_agg(
    --     replace(
    --         E'        CONSTRAINT ' || constraint_name || ' ' || constraint_definition,
    --         template_table_name,
    --         partitions.partition_name,
    --     ),
    --     E',\n'
    --     ORDER BY CASE contype
    --         WHEN 'p' THEN 0
    --         WHEN 'u' THEN 1
    --         ELSE 2
    --     END, contype, conname
    -- ) INTO ddl_constraints
    -- FROM partition_constraints;

    -- FOR constraints IN
    --     SELECT constraint_name
    --          , columns
    --          , constraint_definition
    --       FROM partition_constraints
    -- LOOP
    --     RAISE NOTICE 'constraints: %, %, %', constraints.constraint_name, constraints.columns, constraints.constraint_definition;
    -- END LOOP;

    FOR partitions IN
        WITH dateset AS (
            SELECT "date"
            FROM generate_series(date_trunc(substring(p_interval FROM '\d+\s*(\w+)'), now()) - (p_interval::interval * past), now() + (p_interval::interval * future), p_interval::interval) AS "date"
        ),
        daterange AS (
            -- generate partition bounds
            SELECT to_char("date", suffix) AS part_suffix,
                    "date" AS exclusive_start_time,
                "date" + p_interval::interval AS exclusive_end_time
        FROM dateset
        )
        SELECT
            table_name || part_suffix as partition_name,
            exclusive_start_time,
            exclusive_end_time
        FROM daterange
    LOOP
        IF NOT EXISTS (SELECT 1 FROM current_bounds WHERE current_bounds.lowerbound = partitions.exclusive_start_time AND current_bounds.upperbound = partitions.exclusive_end_time) THEN
        -- Get Constraint definition
        SELECT string_agg(
            replace(
                E'        CONSTRAINT ' || constraint_name || ' ' || constraint_definition,
                template_table_name,
                partitions.partition_name
            ),
            E',\n'
            ORDER BY CASE contype
                WHEN 'p' THEN 0
                WHEN 'u' THEN 1
                ELSE 2
            END, contype, constraint_name
        ) INTO ddl_constraints
        FROM partition_constraints;

        ddl := ddl || format(
/* This alignment is needed to have the right indentation in the generated migration scripts */
$SQL$CREATE TABLE %1$I.%2$I
    PARTITION OF %3$I.%4$I%5$s FOR VALUES FROM (%6$L) TO (%7$L);
$SQL$,          partition_schema,
                partitions.partition_name,
                table_schema,
                table_name,
                CASE
                    WHEN ddl_constraints IS NULL THEN E'\n   '
                    ELSE  E' (\n' || ddl_constraints || E'\n    )'
                END,
                CASE _partitioning_details.keys_data_types
                    WHEN 'timestamp with time zone'     THEN partitions.exclusive_start_time::text
                    WHEN 'timestamp without time zone'  THEN partitions.exclusive_start_time::text
                    WHEN 'date'                         THEN partitions.exclusive_start_time::date::text
                    WHEN 'integer' THEN (EXTRACT(EPOCH FROM partitions.exclusive_start_time)::integer)::text
                    WHEN 'bigint'  THEN (EXTRACT(EPOCH FROM partitions.exclusive_start_time)::bigint * 1000)::text
                END,
                CASE _partitioning_details.keys_data_types
                    WHEN 'timestamp with time zone'     THEN partitions.exclusive_end_time::text
                    WHEN 'timestamp without time zone'  THEN partitions.exclusive_end_time::text
                    WHEN 'date'                         THEN partitions.exclusive_end_time::date::text
                    WHEN 'integer' THEN (EXTRACT(EPOCH FROM partitions.exclusive_end_time)::integer)::text
                    WHEN 'bigint'  THEN (EXTRACT(EPOCH FROM partitions.exclusive_end_time)::bigint * 1000)::text
                END
            );

            RAISE NOTICE 'ddl: "%"', ddl;

            -- RAISE NOTICE 'partition "%", "%", "%"', partitions.partition_name, partitions.exclusive_start_time, partitions.exclusive_end_time;
        END IF;
    END LOOP;

END;
$BODY$;
