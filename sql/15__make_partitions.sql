CREATE OR REPLACE FUNCTION pgpartium.make_partitions (
    p_table_schema text
  , p_table_name text
  , p_partition_name_template text
  , p_interval interval
  , p_past integer = 0
  , p_future integer = 0
  , p_create_default boolean = false
  , p_default_partition_name_template text = NULL
  , p_partition_schema text = NULL
  , p_partition_tablespace text = 'pg_default'
  , p_index_tablespace text = 'pg_default'
  , p_storage_parameters jsonb = '{}'
  , p_template_table_schema text = NULL
  , p_template_table_name text = NULL
  , p_retention interval = '-1'
  , p_timezone text = 'Etc/UTC'
  , p_skip_overlapping boolean = false
)
RETURNS SETOF text
LANGUAGE plpgsql
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
    v_partition_schema         text := COALESCE(p_partition_schema, p_table_schema);
    v_start_timestamp          timestamptz;

BEGIN

    PERFORM set_config('timezone', p_timezone, true);
    PERFORM set_config('client_min_messages', 'warning', true);

    v_parent_exists := pgpartium.table_exists(p_table_schema=>p_table_schema, p_table_name=>p_table_name);
    v_template_exists := pgpartium.table_exists(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name);
    v_is_parent_partitioned := pgpartium.is_table_partitioned(p_table_schema=>p_table_schema, p_table_name=>p_table_name);
    v_partitioning_details := pgpartium.get_partitioning_details(p_table_schema=>p_table_schema, p_table_name=>p_table_name);

    IF NOT v_parent_exists THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT v_is_parent_partitioned THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF v_partitioning_details.strategy != 'RANGE' THEN
        RAISE '"%" partitioning is not supported', v_partitioning_details.strategy
        USING ERRCODE = 'feature_not_supported',
                 HINT = format('table "%1$I"."%2$I" must be partitioned by range', p_table_schema, p_table_name);
    END IF;

    IF v_partitioning_details.number_of_keys > 1 THEN
        RAISE 'multi column partitioned tables are not supported'
        USING ERRCODE = 'feature_not_supported',
                 HINT = format('table "%1$I"."%2$I" is partitioned on more than one column', p_table_schema, p_table_name);
    END IF;

    IF v_partitioning_details.keys_data_types NOT IN ('date', 'timestamptz', 'timestamp', 'int4', 'int8', 'uuid') THEN
        RAISE 'partitioning on data type "%" is not supported', v_partitioning_details.keys_data_types
        USING ERRCODE = 'feature_not_supported',
               DETAIL = format('table "%1$I"."%2$I" is partitioned on a data type that is not supported', p_table_schema, p_table_name),
                 HINT = 'supported data types are: date, timestamp with time zone, timestamp without time zone, integer, bigint, and uuid';
    END IF;

    IF COALESCE(p_partition_name_template, '') = '' THEN
        RAISE 'name template is required'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_create_default AND COALESCE(p_default_partition_name_template, '') = '' THEN
        RAISE 'creating default partition requires default partition name template'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_partition_schema IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_namespace
         WHERE nspname = p_partition_schema
    ) THEN
        RAISE 'partition schema "%" does not exist', p_partition_schema
        USING ERRCODE = 'invalid_schema_name';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_partition_tablespace
    ) THEN
        RAISE 'partition tablespace "%" does not exist', p_partition_tablespace
        USING ERRCODE = 'undefined_object';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_index_tablespace
    ) THEN
        RAISE 'index tablespace "%" does not exist', p_index_tablespace
        USING ERRCODE = 'undefined_object';
    END IF;

    IF (COALESCE(p_template_table_schema, '') > '' OR COALESCE(p_template_table_name, '') > '') AND NOT v_template_exists THEN
        RAISE 'template table "%"."%" does not exist', p_template_table_schema, p_template_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    DROP TABLE IF EXISTS current_bounds;

    CREATE TEMPORARY TABLE current_bounds ON COMMIT DROP AS
    SELECT lower_bound
         , upper_bound
      FROM pgpartium.get_partition_bounds(p_table_schema=>p_table_schema, p_table_name=>p_table_name);

    DROP TABLE IF EXISTS partition_constraints;

    CREATE TEMPORARY TABLE partition_constraints ON COMMIT DROP AS
    WITH template_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
    )
    SELECT template_constraints.constraint_name
         , template_constraints.constraint_type
         , template_constraints.constraint_definition
      FROM template_constraints
      LEFT JOIN parent_constraints
        ON template_constraints.constraint_definition = parent_constraints.constraint_definition
     WHERE parent_constraints.constraint_definition IS NULL;

    DROP TABLE IF EXISTS partition_indexes;

    CREATE TEMPORARY TABLE partition_indexes ON COMMIT DROP AS
    WITH template_indexes AS (
        SELECT index_name
             , is_unique_index
             , index_definition
             , index_predicate
          FROM pgpartium.get_indexes(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_indexes AS (
        SELECT index_name
             , is_unique_index
             , index_definition
             , index_predicate
          FROM pgpartium.get_indexes(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
    )
    SELECT template_indexes.index_name
         , template_indexes.is_unique_index
         , template_indexes.index_definition
         , template_indexes.index_predicate
      FROM template_indexes
      LEFT JOIN parent_indexes
        ON template_indexes.index_definition = parent_indexes.index_definition
     WHERE parent_indexes.index_definition IS NULL;

    DROP TABLE IF EXISTS partition_triggers;

    CREATE TEMPORARY TABLE partition_triggers ON COMMIT DROP AS
    WITH template_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
    )
    SELECT template_triggers.trigger_name
         , template_triggers.is_trigger_enabled
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
                        SELECT upper_bound
                          FROM pgpartium.get_latest_partition(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
                    )
                  , now()
                );

    FOR v_partitions IN
        WITH dateset AS (
            SELECT "date"
              FROM generate_series((date_trunc(substring(p_interval::text FROM '\d+\s*(\w+)'), v_start_timestamp) - (p_interval * p_past)), (now() + (p_interval * p_future)), p_interval) AS "date"
        )
        SELECT replace(
                    replace(
                        to_char("date", p_partition_name_template)
                      , '{table_name}'
                      , p_table_name
                    )
                  , '{table_schema}'
                  , p_table_schema
               ) AS partition_name
             , "date" AS lower_bound
             , ("date" + p_interval) AS upper_bound
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

        -- Skip if this partition will be older than the retention period.
        IF age(now(), CAST(v_partitions.upper_bound AS timestamptz)) > NULLIF(p_retention, '-1') THEN
            CONTINUE;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM current_bounds
             WHERE current_bounds.lower_bound = v_partitions.lower_bound
               AND current_bounds.upper_bound = v_partitions.upper_bound
        ) THEN

            -- Get constraint definition.
            SELECT string_agg(
                        format(
                            '        CONSTRAINT %1$I %2$s'
                          , replace(                           --<1>
                                constraint_name
                              , p_template_table_name
                              , v_partitions.partition_name
                            )
                          , constraint_definition              --<2>
                        )
                      , E',\n'
                        ORDER BY CASE constraint_type
                                   WHEN 'p'
                                     THEN 0
                                   WHEN 'u'
                                     THEN 1
                                   ELSE 2
                                 END
                               , replace(
                                     constraint_name
                                   , p_template_table_name
                                   , v_partitions.partition_name
                                 )
                   )
              INTO v_constraints
              FROM partition_constraints;

            -- Get index create statement.
            SELECT string_agg(
                       format(
                           E'%1$s%2$s;\n'
                         , replace(
                               format(
                                   E'CREATE %1$s %2$I\n    ON %3$I.%4$I\n %5$s'
                                 , CASE                               --<1>
                                     WHEN is_unique_index
                                       THEN 'UNIQUE INDEX'
                                     ELSE 'INDEX'
                                   END
                                 , replace(                           --<2>
                                       index_name
                                     , p_template_table_name
                                     , v_partitions.partition_name
                                   )
                                 , v_partition_schema                 --<3>
                                 , v_partitions.partition_name        --<4>
                                 , index_definition                   --<5>
                               )
                               -- We cannot use format here because NULL is treated as an empty string for `s` formats.
                             , COALESCE(' ' || index_predicate, '')
                             , CASE
                                 WHEN p_index_tablespace != 'pg_default'
                                   THEN format(
                                            E'\nTABLESPACE %1$I\n %2$s'
                                          , p_index_tablespace          --<1>
                                          , index_predicate             --<2>
                                        )
                                 ELSE format(E'\n %1$s', index_predicate)
                               END
                           )
                         , CASE
                             WHEN index_predicate IS NULL AND p_index_tablespace != 'pg_default'
                               THEN format(E'\nTABLESPACE %1$I', p_index_tablespace)
                             ELSE ''
                           END
                       )
                     , E'\n'
                       ORDER BY CASE is_unique_index
                                  WHEN true
                                    THEN 0
                                  WHEN false
                                    THEN 1
                                END
                              , replace(
                                    index_name
                                  , p_template_table_name
                                  , v_partitions.partition_name
                                )
                   )
              INTO v_indexes
              FROM partition_indexes;

            -- Get create trigger statement.
            SELECT string_agg(
                       format(
                           E'CREATE %1$s %2$I %3$s %4$s\n    ON %5$I.%6$I\n   %7$s;\n%8$s'
                         , CASE                                         --<1>
                             WHEN is_constraint_trigger
                               THEN 'CONSTRAINT TRIGGER'
                             ELSE 'TRIGGER'
                           END
                         , replace(                                     --<2>
                               trigger_name
                             , p_template_table_name
                             , v_partitions.partition_name
                           )
                         , event_timing                                 --<3>
                         , trigger_event                                --<4>
                         , v_partition_schema                           --<5>
                         , v_partitions.partition_name                  --<6>
                         , trigger_body                                 --<7>
                         , CASE                                         --<8>
                             WHEN NOT is_trigger_enabled
                               THEN format(
                                        E'\nALTER TABLE %1$I.%2$I\n    DISABLE TRIGGER %3$I;\n'
                                      , v_partition_schema                                         --<1>
                                      , v_partitions.partition_name                                --<2>
                                      , replace(                                                   --<3>
                                         trigger_name
                                       , p_template_table_name
                                       , v_partitions.partition_name
                                     )
                                )
                               ELSE ''
                            END
                       )
                       , E'\n'
                       ORDER BY replace(
                                    trigger_name
                                  , p_template_table_name
                                  , v_partitions.partition_name
                                )
                   )
              INTO v_triggers
              FROM partition_triggers;

            -- Get storage parameters.
            -- We cannot use format here because NULL is treated as an empty string for `s` formats.
            SELECT COALESCE(E'\nWITH (' || string_agg(format('%1$I = %2$L', key, value), ', ') || ')', '')
              INTO v_storage_clause
              FROM jsonb_each_text(p_storage_parameters);

            IF v_ddl != '' THEN
                v_ddl := format(E'%1$s\n', v_ddl);
            END IF;

            -- Partition definition.
            v_ddl := v_ddl || format(
                E'CREATE TABLE %1$I.%2$I\n    PARTITION OF %3$I.%4$I%5$s\n    FOR VALUES FROM (%6$L) TO (%7$L)%8$s%9$s'
              , v_partition_schema                                                             -- <1>
              , v_partitions.partition_name                                                    -- <2>
              , p_table_schema                                                                 -- <3>
              , p_table_name                                                                   -- <4>
              -- We cannot use format here because NULL is treated as an empty string for `s` formats.
              , COALESCE(E' (\n' || v_constraints || E'\n    )', '')                           -- <5>
              , CASE v_partitioning_details.keys_data_types                                    -- <6>
                  WHEN 'timestamptz'
                    THEN v_partitions.lower_bound::timestamptz::text
                  WHEN 'timestamp'
                    THEN v_partitions.lower_bound::timestamp::text
                  WHEN 'date'
                    THEN v_partitions.lower_bound::date::text
                  WHEN 'int4'
                    THEN (EXTRACT(EPOCH FROM v_partitions.lower_bound)::integer)::text
                  WHEN 'int8'
                    THEN (EXTRACT(EPOCH FROM v_partitions.lower_bound)::bigint * 1000)::text
                  WHEN 'uuid'
                    THEN (
                        overlay(
                            overlay(
                                pgpartium.gen_uuid_v7(v_partitions.lower_bound)::text
                                PLACING '0000' FROM 15 FOR 4
                            )
                            PLACING '0000-000000000000' FROM 20
                        )
                    )::text
                END
              , CASE v_partitioning_details.keys_data_types                                    -- <7>
                  WHEN 'timestamptz'
                    THEN v_partitions.upper_bound::timestamptz::text
                  WHEN 'timestamp'
                    THEN v_partitions.upper_bound::timestamp::text
                  WHEN 'date'
                    THEN v_partitions.upper_bound::date::text
                  WHEN 'int4'
                    THEN (EXTRACT(EPOCH FROM v_partitions.upper_bound)::integer)::text
                  WHEN 'int8'
                    THEN (EXTRACT(EPOCH FROM v_partitions.upper_bound)::bigint * 1000)::text
                  WHEN 'uuid'
                    THEN (
                        overlay(
                            overlay(
                                pgpartium.gen_uuid_v7(v_partitions.upper_bound)::text
                                PLACING '0000' FROM 15 FOR 4
                            )
                            PLACING '0000-000000000000' FROM 20
                        )
                    )::text
                END
              , v_storage_clause                                                               -- <8>
              , CASE                                                                           -- <9>
                  WHEN p_partition_tablespace != 'pg_default'
                    THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
                  ELSE ''
                END
            );

            -- We cannot use format here because NULL is treated as an empty string for `s` formats.
            v_ddl := COALESCE(v_ddl || E'\n' || v_indexes, v_ddl);
            v_ddl := COALESCE(v_ddl || E'\n' || v_triggers, v_ddl);

        END IF;

    END LOOP;

    -- Create default partition: START
    IF p_create_default
    AND NOT EXISTS (
        SELECT pgpartium.get_default_partition(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
    ) THEN
        SELECT replace(
                    replace(
                        p_default_partition_name_template
                      , '{table_name}'
                      , p_table_name)
                  , '{table_schema}'
                  , p_table_schema
               )
          INTO v_default_partition_name;

        -- Get constraint definition.
        SELECT string_agg(
                    format(
                        '        CONSTRAINT %1$I %2$s'
                      , replace(                           --<1>
                            constraint_name
                          , p_template_table_name
                          , v_default_partition_name
                        )
                      , constraint_definition              --<2>
                    )
                  , E',\n'
                    ORDER BY CASE constraint_type
                               WHEN 'p'
                                 THEN 0
                               WHEN 'u'
                                 THEN 1
                               ELSE 2
                             END
                           , replace(
                                 constraint_name
                               , p_template_table_name
                               , v_default_partition_name
                             )
               )
          INTO v_constraints
          FROM partition_constraints;

        -- Get index create statement.
        SELECT string_agg(
                   format(
                       E'%1$s%2$s;\n'
                     , replace(
                           format(
                               E'CREATE %1$s %2$I\n    ON %3$I.%4$I\n %5$s'
                             , CASE                               --<1>
                                 WHEN is_unique_index
                                   THEN 'UNIQUE INDEX'
                                 ELSE 'INDEX'
                               END
                             , replace(                           --<2>
                                   index_name
                                 , p_template_table_name
                                 , v_default_partition_name
                               )
                             , v_partition_schema                 --<3>
                             , v_default_partition_name           --<4>
                             , index_definition                   --<5>
                           )
                           -- We cannot use format here because NULL is treated as an empty string for `s` formats.
                         , COALESCE(' ' || index_predicate, '')
                         , CASE
                             WHEN p_index_tablespace != 'pg_default'
                               THEN format(
                                        E'\nTABLESPACE %1$I\n %2$s'
                                      , p_index_tablespace              --<1>
                                      , index_predicate                 --<2>
                                    )
                             ELSE format(E'\n %1$s', index_predicate)
                           END
                       )
                     , CASE
                         WHEN index_predicate IS NULL AND p_index_tablespace != 'pg_default'
                           THEN format(E'\nTABLESPACE %1$I', p_index_tablespace)
                         ELSE ''
                       END
                   )
                 , E'\n'
                   ORDER BY CASE is_unique_index
                              WHEN true
                                THEN 0
                              WHEN false
                                THEN 1
                            END
                          , replace(
                                index_name
                              , p_template_table_name
                              , v_partitions.partition_name
                            )
               )
          INTO v_indexes
          FROM partition_indexes;

        -- Get create trigger statement.
        SELECT string_agg(
                   format(
                       E'CREATE %1$s %2$I %3$s %4$s\n    ON %5$I.%6$I\n   %7$s;\n%8$s'
                     , CASE                                         --<1>
                         WHEN is_constraint_trigger
                           THEN 'CONSTRAINT TRIGGER'
                         ELSE 'TRIGGER'
                       END
                     , replace(                                     --<2>
                           trigger_name
                         , p_template_table_name
                         , v_default_partition_name
                       )
                     , event_timing                                 --<3>
                     , trigger_event                                --<4>
                     , v_partition_schema                           --<5>
                     , v_default_partition_name                     --<6>
                     , trigger_body                                 --<7>
                     , CASE                                         --<8>
                         WHEN NOT is_trigger_enabled
                           THEN format(
                                    E'\nALTER TABLE %1$I.%2$I\n    DISABLE TRIGGER %3$I;\n'
                                  , v_partition_schema              --<1>
                                  , v_default_partition_name        --<2>
                                  , replace(                        --<3>
                                     trigger_name
                                   , p_template_table_name
                                   , v_default_partition_name
                                 )
                            )
                           ELSE ''
                        END
                   )
                   , E'\n'
                   ORDER BY replace(
                                trigger_name
                              , p_template_table_name
                              , v_default_partition_name
                            )
               )
          INTO v_triggers
          FROM partition_triggers;

        -- Get storage parameters.
        -- We cannot use format here because NULL is treated as an empty string for `s` formats.
        SELECT COALESCE(E'\nWITH (' || string_agg(format('%1$I = %2$L', key, value), ', ') || ')', '')
          INTO v_storage_clause
          FROM jsonb_each_text(p_storage_parameters);

        IF v_ddl != '' THEN
            v_ddl := format(E'%1$s\n', v_ddl);
        END IF;

        -- Partition definition.
        v_ddl := v_ddl || format(
/*
This alignment is needed to have the right indentation in the generated migration scripts.
We could use new lines characters instead for the alignment, but that would require escaping with `E`
which does not work with dollar quoting.
*/
            E'CREATE TABLE %1$I.%2$I\n    PARTITION OF %3$I.%4$I%5$s\n    DEFAULT%6$s%7$s;'
-- $SQL$CREATE TABLE %1$I.%2$I
--     PARTITION OF %3$I.%4$I%5$s
--     DEFAULT%6$s%7$s;
-- $SQL$,
, v_partition_schema                                              -- <1>
          , v_default_partition_name                                        -- <2>
          , p_table_schema                                                  -- <3>
          , p_table_name                                                    -- <4>
          -- We cannot use format here because NULL is treated as an empty string for `s` formats.
          , COALESCE(E' (\n' || v_constraints || E'\n    )', '')            -- <5>
          , v_storage_clause                                                -- <6>
          , CASE                                                            -- <7>
              WHEN p_partition_tablespace != 'pg_default'
                THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
              ELSE ''
            END
        );

        -- We cannot use format here because NULL is treated as an empty string for `s` formats.
        v_ddl := COALESCE(v_ddl || E'\n' || v_indexes, v_ddl);
        v_ddl := COALESCE(v_ddl || E'\n' || v_triggers, v_ddl);

    END IF;
    -- Create default partition: END

    IF v_ddl != '' THEN
        RETURN NEXT v_ddl;
    END IF;

    RETURN;

END;
$BODY$;
