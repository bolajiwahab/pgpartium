CREATE OR REPLACE FUNCTION pgpartium.generate_partitions (
    table_schema text
  , table_name text
  , p_interval text
  , past integer
  , future integer
  , prefix text
  , suffix text
  , partition_schema text = 'public'
  , partition_tablespace text = NULL
  , storage_parameters jsonb = NULL
  , template_table_schema text = NULL
  , template_table_name text = NULL
  , timezone text = 'UTC'
)
RETURNS SETOF text
LANGUAGE plpgsql
SET search_path = ''
AS $BODY$
DECLARE
    partitions record;
    _table_exists boolean;
    _template_exists boolean;
    _is_table_partitioned boolean;
    _partitioning_details record;
    ddl                       text := '';
    ddl_indexes               text;
    ddl_constraints           text;
    ddl_triggers              text;
    storage_clause text := '';
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

    CREATE TEMPORARY TABLE partition_constraints ON COMMIT DROP AS
    WITH template_constraints AS (
        SELECT constraint_name
             , contype
             , columns
             , constraint_definition
          FROM pgpartium.get_constraints(template_table_schema, template_table_name)
    )
    , parent_constraints AS (
        SELECT constraint_name
             , contype
             , columns
             , constraint_definition
          FROM pgpartium.get_constraints(table_schema, table_name)
    )
    SELECT template_constraints.constraint_name
         , template_constraints.contype
         , template_constraints.columns
         , template_constraints.constraint_definition
      FROM template_constraints
      LEFT JOIN parent_constraints
        ON template_constraints.constraint_definition = parent_constraints.constraint_definition
     WHERE parent_constraints.constraint_definition IS NULL;

    CREATE TEMPORARY TABLE partition_indexes ON COMMIT DROP AS
    WITH template_indexes AS (
        SELECT index_name
             , is_unique_index
             , index_definition
             , index_predicate
          FROM pgpartium.get_indexes(template_table_schema, template_table_name)
    )
    , parent_indexes AS (
        SELECT index_name
             , is_unique_index
             , index_definition
             , index_predicate
          FROM pgpartium.get_indexes(table_schema, table_name)
    )
    SELECT template_indexes.index_name
         , template_indexes.is_unique_index
         , template_indexes.index_definition
         , template_indexes.index_predicate
      FROM template_indexes
      LEFT JOIN parent_indexes
        ON template_indexes.index_definition = parent_indexes.index_definition
     WHERE parent_indexes.index_definition IS NULL;

    CREATE TEMPORARY TABLE partition_triggers ON COMMIT DROP AS
    WITH template_triggers AS (
        SELECT trigger_name
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(template_table_schema, template_table_name)
    )
    , parent_triggers AS (
        SELECT trigger_name
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(table_schema, table_name)
    )
    SELECT template_triggers.trigger_name
         , template_triggers.is_constraint_trigger
         , template_triggers.event_timing
         , template_triggers.trigger_event
         , template_triggers.trigger_body
      FROM template_triggers
      LEFT JOIN parent_triggers
        ON template_triggers.event_timing = parent_triggers.event_timing
       AND template_triggers.trigger_event = parent_triggers.trigger_event
       AND template_triggers.trigger_body = parent_triggers.trigger_body
     WHERE parent_triggers.trigger_body IS NULL;

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
        IF NOT EXISTS (
            SELECT 1
              FROM current_bounds
             WHERE current_bounds.lowerbound = partitions.exclusive_start_time
               AND current_bounds.upperbound = partitions.exclusive_end_time
        ) THEN
            -- Get constraint definition
            SELECT string_agg(
                '        CONSTRAINT '
                || format('%1$I', replace(constraint_name, template_table_name, partitions.partition_name))
                || ' '
                || constraint_definition,
                E',\n'
                ORDER BY CASE contype
                    WHEN 'p' THEN 0
                    WHEN 'u' THEN 1
                    ELSE 2
                END, contype
            ) INTO ddl_constraints
            FROM partition_constraints;

            -- Get index create statement
            SELECT string_agg(
                replace(
                    'CREATE '
                    || CASE WHEN is_unique_index THEN 'UNIQUE INDEX ' ELSE 'INDEX ' END
                    || format('%1$I', replace(index_name, template_table_name, partitions.partition_name))
                    || E'\n    ON '
                    || format('%1$I.%2$I', partition_schema, partitions.partition_name)
                    || E'\n '
                    || index_definition
                , coalesce(index_predicate, '')
                , 'TABLESPACE ' || partition_tablespace || ' ' || coalesce(index_predicate, '')
                )
                || CASE WHEN index_predicate IS NULL THEN E'\nTABLESPACE ' || partition_tablespace ELSE '' END
                || E';\n'
              , E'\n'
            ) INTO ddl_indexes
            FROM partition_indexes;

            -- Get create trigger statement
            SELECT string_agg(
                'CREATE '
                || CASE WHEN is_constraint_trigger THEN 'CONSTRAINT TRIGGER ' ELSE 'TRIGGER ' END
                || format('%1$I', replace(trigger_name, template_table_name, partitions.partition_name))
                || ' '
                || event_timing
                || ' '
                || trigger_event
                || E'\n    ON '
                || format('%1$I.%2$I', partition_schema, partitions.partition_name)
                || ' '
                || trigger_body
                || E';\n'
              , E'\n' ORDER BY trigger_name
            ) INTO ddl_triggers
            FROM partition_triggers;

            -- Get storage parameters
            SELECT coalesce(E'\nWITH (' || string_agg(format('%I = %L', key, value), ', ') || ')', '')
              INTO storage_clause
              FROM jsonb_each_text(storage_parameters);

            -- Get table definition
            IF ddl != '' THEN
                ddl := ddl || E'\n';
            END IF;

        ddl := ddl || format(
/* This alignment is needed to have the right indentation in the generated migration scripts */
$SQL$CREATE TABLE %1$I.%2$I
    PARTITION OF %3$I.%4$I%5$s FOR VALUES FROM (%6$L) TO (%7$L)%8$s%9$s;
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
                END,
                storage_clause,
                coalesce(format(E'\nTABLESPACE %I', partition_tablespace), '')
            );

            IF ddl_indexes IS NOT NULL THEN
                ddl := ddl || E'\n' || ddl_indexes;
            END IF;

            IF ddl_triggers IS NOT NULL THEN
                ddl := ddl || E'\n' || ddl_triggers;
            END IF;

            RAISE NOTICE 'ddl: "%"', ddl;

        END IF;
    END LOOP;

END;
$BODY$;
