CREATE OR REPLACE FUNCTION pgpartium.generate_partitions (
    p_table_schema text
  , p_table_name text
  , p_partition_name_template text
  , p_interval text
  , p_past integer = 0
  , p_future integer = 0
  , p_create_default boolean = false
  , p_partition_schema text = 'public'
  , p_partition_tablespace text = 'pg_default'
  , p_storage_parameters jsonb = '{}'
  , p_template_table_schema text = NULL
  , p_template_table_name text = NULL
  , p_retention interval = NULL
  , p_timezone text = 'UTC'
  , p_skip_overlapping boolean = false
)
RETURNS SETOF text
LANGUAGE plpgsql
SET search_path TO ''
AS $BODY$
DECLARE
    v_partitions               record;
    v_parent_exists            boolean;
    v_template_exists          boolean;
    v_is_parent_partitioned    boolean;
    v_partitioning_details     record;
    v_ddl                      text := '';
    v_indexes                  text;
    v_constraints              text;
    v_triggers                 text;
    v_storage_clause           text;
    v_default_partition_name   text;
    v_start_timestamp          timestamptz;

BEGIN

    PERFORM set_config('timezone', p_timezone, true);

    v_parent_exists := pgpartium.table_exists(p_table_schema, p_table_name);
    v_template_exists := pgpartium.table_exists(p_template_table_schema, p_template_table_name);
    v_is_parent_partitioned := pgpartium.is_table_partitioned(p_table_schema, p_table_name);
    v_partitioning_details := pgpartium.get_partitioning_details(p_table_schema, p_table_name);

    IF NOT v_parent_exists THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF (p_template_table_schema IS NOT NULL OR p_template_table_name IS NOT NULL) AND NOT v_template_exists THEN
        RAISE 'template table "%"."%" does not exist', p_template_table_schema, p_template_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF COALESCE(p_partition_name_template, '') = '' THEN
        RAISE 'name template is required'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF NOT v_is_parent_partitioned THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF v_partitioning_details.strategy != 'RANGE' THEN
        RAISE '"%" partitioning is not supported', v_partitioning_details.strategy
        USING ERRCODE = 'undefined_table',
                 HINT = 'table ' || '"' || p_table_schema || '"' || '.' || '"' || p_table_name || '"' || ' must be partitioned by range';
    END IF;

    IF v_partitioning_details.number_of_keys > 1 THEN
        RAISE 'multi column partitioned tables are not supported'
        USING ERRCODE = 'undefined_table',
                 HINT = 'table ' || '"' || p_table_schema || '"' || '.' || '"' || p_table_name || '"' || ' is partitioned on more than one column';
    END IF;

    IF v_partitioning_details.keys_data_types NOT IN ('date', 'timestamptz', 'timestamp', 'int4', 'int8') THEN
        RAISE 'partitioning on data type "%" is not supported', v_partitioning_details.keys_data_types
        USING ERRCODE = 'undefined_table',
               DETAIL = 'table ' || '"' || p_table_schema || '"' || '.' || '"' || p_table_name || '"' || ' is partitioned on a data type that is not supported',
                 HINT = 'supported data types are: date, timestamp with time zone, timestamp without time zone, integer, and bigint';
    END IF;

    CREATE TEMPORARY TABLE current_bounds ON COMMIT DROP AS
    SELECT lower_bound
         , upper_bound
      FROM pgpartium.get_partition_bounds(p_table_schema, p_table_name);

    CREATE TEMPORARY TABLE partition_constraints ON COMMIT DROP AS
    WITH template_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_template_table_schema, p_template_table_name)
    )
    , parent_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_table_schema, p_table_name)
    )
    SELECT template_constraints.constraint_name
         , template_constraints.constraint_type
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
          FROM pgpartium.get_indexes(p_template_table_schema, p_template_table_name)
    )
    , parent_indexes AS (
        SELECT index_name
             , is_unique_index
             , index_definition
             , index_predicate
          FROM pgpartium.get_indexes(p_table_schema, p_table_name)
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
          FROM pgpartium.get_triggers(p_template_table_schema, p_template_table_name)
    )
    , parent_triggers AS (
        SELECT trigger_name
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(p_table_schema, p_table_name)
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

    SELECT INTO v_start_timestamp
                COALESCE(
                    (
                        SELECT lower_bound
                          FROM pgpartium.get_latest_partition(p_table_schema, p_table_name)
                    )
                  , now()
                );

    FOR v_partitions IN
        WITH dateset AS (
            SELECT "date"
              FROM generate_series((date_trunc(substring(p_interval FROM '\d+\s*(\w+)'), v_start_timestamp) - (p_interval::interval * p_past)), (now() + (p_interval::interval * p_future)), p_interval::interval) AS "date"
        )
        SELECT replace(
                    replace(
                        to_char("date", p_partition_name_template)
                      , '{table}'
                      , p_table_name
                    )
                  , '{schema}'
                  , p_table_schema
               ) AS partition_name
             , "date" AS lower_bound
             , ("date" + p_interval::interval) AS upper_bound
          FROM dateset
    LOOP

        IF p_skip_overlapping
        AND EXISTS (
            SELECT 1
              FROM current_bounds
             WHERE (current_bounds.lower_bound, current_bounds.upper_bound) OVERLAPS (v_partitions.lower_bound, v_partitions.upper_bound)
        ) THEN
            CONTINUE;
        END IF;

        IF age(CAST(v_partitions.upper_bound AS timestamptz)) > p_retention THEN
            CONTINUE;
        END IF;
         
        IF NOT EXISTS (
            SELECT 1
              FROM current_bounds
             WHERE current_bounds.lower_bound = v_partitions.lower_bound
               AND current_bounds.upper_bound = v_partitions.upper_bound
        ) THEN

            -- Get constraint definition
            SELECT string_agg(
                '        CONSTRAINT '
                || format('%1$I', replace(constraint_name, p_template_table_name, v_partitions.partition_name))
                || ' '
                || constraint_definition,
                E',\n'
                ORDER BY CASE constraint_type
                    WHEN 'p' THEN 0
                    WHEN 'u' THEN 1
                    ELSE 2
                END
            ) INTO v_constraints
            FROM partition_constraints;

            -- Get index create statement
            SELECT string_agg(
                    replace(
                        'CREATE '
                        || CASE WHEN is_unique_index THEN 'UNIQUE INDEX ' ELSE 'INDEX ' END
                        || format('%1$I', replace(index_name, p_template_table_name, v_partitions.partition_name))
                        || E'\n    ON '
                        || format('%1$I.%2$I', p_partition_schema, v_partitions.partition_name)
                        || E'\n '
                        || index_definition
                        , COALESCE(' ' || index_predicate, '')
                        , CASE
                            WHEN p_partition_tablespace != 'pg_default'
                              THEN format(E'\nTABLESPACE %1$I', p_partition_tablespace)
                            ELSE ''
                          END
                          || E'\n ' || COALESCE(index_predicate, '')
                    )
                    || CASE
                         WHEN index_predicate IS NULL AND p_partition_tablespace != 'pg_default'
                           THEN format(E'\nTABLESPACE %1$I', p_partition_tablespace)
                           ELSE ''
                       END
                    || E';\n'
                    , E'\n'
                   ) INTO v_indexes
              FROM partition_indexes;

            -- Get create trigger statement
            SELECT string_agg(
                    'CREATE '
                    || CASE WHEN is_constraint_trigger THEN 'CONSTRAINT TRIGGER ' ELSE 'TRIGGER ' END
                    || format('%1$I', replace(trigger_name, p_template_table_name, v_partitions.partition_name))
                    || ' '
                    || event_timing
                    || ' '
                    || trigger_event
                    || E'\n    ON '
                    || format('%1$I.%2$I', p_partition_schema, v_partitions.partition_name)
                    || E'\n   '
                    || trigger_body
                    || E';\n'
                    , E'\n'
                    ORDER BY trigger_name
                   ) INTO v_triggers
              FROM partition_triggers;

            -- Get storage parameters
            SELECT COALESCE(E'\nWITH (' || string_agg(format('%1$I = %2$L', key, value), ', ') || ')', '')
              INTO v_storage_clause
              FROM jsonb_each_text(p_storage_parameters);

            IF v_ddl != '' THEN
                v_ddl := v_ddl || E'\n';
            END IF;

            -- Partition definition
            v_ddl := v_ddl || format(
/* This alignment is needed to have the right indentation in the generated migration scripts */
$SQL$CREATE TABLE %1$I.%2$I
    PARTITION OF %3$I.%4$I%5$s
    FOR VALUES FROM (%6$L) TO (%7$L)%8$s%9$s;
$SQL$,          p_partition_schema                                                                                           -- <1>
              , v_partitions.partition_name                                                                                  -- <2>
              , p_table_schema                                                                                               -- <3>
              , p_table_name                                                                                                 -- <4>
              , CASE                                                                                                         -- <5>
                    WHEN v_constraints IS NULL THEN E''
                    ELSE  E' (\n' || v_constraints || E'\n    )'
                END
              , CASE v_partitioning_details.keys_data_types                                                                  -- <6>
                    WHEN 'timestamptz' THEN v_partitions.lower_bound::text
                    WHEN 'timestamp'   THEN v_partitions.lower_bound::text
                    WHEN 'date'        THEN v_partitions.lower_bound::date::text
                    WHEN 'int4'        THEN (EXTRACT(EPOCH FROM v_partitions.lower_bound)::integer)::text
                    WHEN 'int8'        THEN (EXTRACT(EPOCH FROM v_partitions.lower_bound)::bigint * 1000)::text
                END
              , CASE v_partitioning_details.keys_data_types                                                                  -- <7>
                    WHEN 'timestamptz' THEN v_partitions.upper_bound::text
                    WHEN 'timestamp'   THEN v_partitions.upper_bound::text
                    WHEN 'date'        THEN v_partitions.upper_bound::date::text
                    WHEN 'int4'        THEN (EXTRACT(EPOCH FROM v_partitions.upper_bound)::integer)::text
                    WHEN 'int8'        THEN (EXTRACT(EPOCH FROM v_partitions.upper_bound)::bigint * 1000)::text
                END
              , v_storage_clause                                                                                             -- <8>
              , CASE                                                                                                         -- <9>
                  WHEN p_partition_tablespace != 'pg_default'
                    THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
                    ELSE ''
                END
            );

            IF v_indexes IS NOT NULL THEN
                v_ddl := v_ddl || E'\n' || v_indexes;
            END IF;

            IF v_triggers IS NOT NULL THEN
                v_ddl := v_ddl || E'\n' || v_triggers;
            END IF;

        END IF;

    END LOOP;

   -- Create default partition: START
    IF p_create_default
    AND NOT EXISTS (
        SELECT pgpartium.get_default_partition(p_table_schema, p_table_name)
    ) THEN
        SELECT p_table_name || '__default'
          INTO v_default_partition_name;
        -- Get constraint definition
        SELECT string_agg(
            '        CONSTRAINT '
            || format('%1$I', replace(constraint_name, p_template_table_name, v_default_partition_name))
            || ' '
            || constraint_definition,
            E',\n'
            ORDER BY CASE constraint_type
                WHEN 'p' THEN 0
                WHEN 'u' THEN 1
                ELSE 2
            END
        ) INTO v_constraints
        FROM partition_constraints;

        -- Get index create statement
        SELECT string_agg(
                replace(
                    'CREATE '
                    || CASE WHEN is_unique_index THEN 'UNIQUE INDEX ' ELSE 'INDEX ' END
                    || format('%1$I', replace(index_name, p_template_table_name, v_default_partition_name))
                    || E'\n    ON '
                    || format('%1$I.%2$I', p_partition_schema, v_default_partition_name)
                    || E'\n '
                    || index_definition
                    , COALESCE(index_predicate, '')
                    , CASE
                        WHEN p_partition_tablespace != 'pg_default'
                            THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
                        ELSE ''
                        END
                        || E'\n ' || COALESCE(index_predicate, '')
                )
                || CASE
                        WHEN index_predicate IS NULL AND p_partition_tablespace != 'pg_default'
                        THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
                        ELSE ''
                    END
                || E';\n'
                , E'\n'
                ) INTO v_indexes
            FROM partition_indexes;

        -- Get create trigger statement
        SELECT string_agg(
                'CREATE '
                || CASE WHEN is_constraint_trigger THEN 'CONSTRAINT TRIGGER ' ELSE 'TRIGGER ' END
                || format('%1$I', replace(trigger_name, p_template_table_name, v_default_partition_name))
                || ' '
                || event_timing
                || ' '
                || trigger_event
                || E'\n    ON '
                || format('%1$I.%2$I', p_partition_schema, v_default_partition_name)
                || E'\n   '
                || trigger_body
                || E';\n'
                , E'\n'
                ORDER BY trigger_name
                ) INTO v_triggers
            FROM partition_triggers;

        -- Get storage parameters
        SELECT COALESCE(E'\nWITH (' || string_agg(format('%I = %L', key, value), ', ') || ')', '')
            INTO v_storage_clause
            FROM jsonb_each_text(p_storage_parameters);

        IF v_ddl != '' THEN
            v_ddl := v_ddl || E'\n';
        END IF;

        v_ddl := v_ddl || format(

/* This alignment is needed to have the right indentation in the generated migration scripts */
$SQL$CREATE TABLE %1$I.%2$I
    PARTITION OF %3$I.%4$I%5$s
    DEFAULT%6$s%7$s;
$SQL$,      p_partition_schema                                              -- <1>
          , v_default_partition_name                                        -- <2>
          , p_table_schema                                                  -- <3>
          , p_table_name                                                    -- <4>
          , CASE                                                            -- <5>
                WHEN v_constraints IS NULL THEN E''
                ELSE  E' (\n' || v_constraints || E'\n    )'
            END,
            v_storage_clause                                                -- <6>
          , CASE                                                            -- <7>
                WHEN p_partition_tablespace != 'pg_default'
                THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
                ELSE ''
            END
        );
    END IF;

    IF v_indexes IS NOT NULL THEN
        v_ddl := v_ddl || E'\n' || v_indexes;
    END IF;

    IF v_triggers IS NOT NULL THEN
        v_ddl := v_ddl || E'\n' || v_triggers;
    END IF;

    -- Create default partition: END

    IF v_ddl != '' THEN
        RETURN NEXT v_ddl;
    END IF;

    RETURN;

END;
$BODY$;
