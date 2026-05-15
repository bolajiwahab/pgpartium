CREATE OR REPLACE FUNCTION pgpartium.make_partitions (
    p_table_schema text
  , p_table_name text
  , p_partition_name_template text
  , p_interval interval
  , p_past integer DEFAULT 0
  , p_future integer DEFAULT 0
  , p_create_default boolean DEFAULT false
  , p_default_partition_name_template text DEFAULT NULL
  , p_partition_schema text DEFAULT NULL
  , p_partition_tablespace text DEFAULT 'pg_default'
  , p_partition_storage_parameters jsonb DEFAULT '{}'
  , p_index_tablespace text DEFAULT 'pg_default'
  , p_template_table_schema text DEFAULT NULL
  , p_template_table_name text DEFAULT NULL
  , p_retention interval DEFAULT NULL
  , p_timezone text DEFAULT 'Etc/UTC'
  , p_skip_overlapping boolean DEFAULT false
  , p_idempotent_ddl boolean DEFAULT false
)
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_partition                record;
    v_partitioning_details     record;
    v_ddl                      text := '';
    v_indexes                  text;
    v_constraints              text;
    v_triggers                 text;
    v_storage_clause           text;
    v_partition_schema         text := COALESCE(p_partition_schema, p_table_schema);
    v_start_timestamp          timestamptz;
    v_interval_unit            text;

BEGIN

    PERFORM set_config('timezone', p_timezone, true);

    IF p_interval = interval '0' THEN
        RAISE 'interval must not be zero'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF COALESCE(p_partition_name_template, '') = '' THEN
        RAISE 'partition name template is required'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    v_partitioning_details := pgpartium.get_partitioning_details(p_table_schema=>p_table_schema, p_table_name=>p_table_name);

    IF NOT pgpartium.table_exists(p_table_schema=>p_table_schema, p_table_name=>p_table_name) THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT pgpartium.is_table_partitioned(p_table_schema=>p_table_schema, p_table_name=>p_table_name) THEN
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

    IF p_create_default AND COALESCE(p_default_partition_name_template, '') = '' THEN
        RAISE 'creating default partition requires default partition name template'
        USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_partition_schema IS NOT NULL
    AND NOT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_namespace
         WHERE nspname = p_partition_schema
    ) THEN
        RAISE 'partition schema "%" does not exist', p_partition_schema
        USING ERRCODE = 'invalid_schema_name';
    END IF;

    IF NOT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_partition_tablespace
    ) THEN
        RAISE 'partition tablespace "%" does not exist', p_partition_tablespace
        USING ERRCODE = 'undefined_object';
    END IF;

    IF NOT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_index_tablespace
    ) THEN
        RAISE 'index tablespace "%" does not exist', p_index_tablespace
        USING ERRCODE = 'undefined_object';
    END IF;

    IF (COALESCE(p_template_table_schema, '') > '' OR COALESCE(p_template_table_name, '') > '')
    AND NOT pgpartium.table_exists(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name) THEN
        RAISE 'template table "%"."%" does not exist', p_template_table_schema, p_template_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    SELECT CASE
             WHEN EXTRACT(year FROM p_interval) <> 0
               THEN 'year'
             WHEN EXTRACT(month FROM p_interval) <> 0
               THEN 'month'
             WHEN EXTRACT(day FROM p_interval) <> 0 AND EXTRACT(day FROM p_interval) % 7 = 0
               THEN 'week'
             WHEN EXTRACT(day FROM p_interval) <> 0
               THEN 'day'
             WHEN EXTRACT(hour FROM p_interval) <> 0
               THEN 'hour'
             WHEN EXTRACT(minute FROM p_interval) <> 0
               THEN 'minute'
             ELSE 'second'
           END
      INTO v_interval_unit;

    SELECT COALESCE(
               (
                    SELECT upper_bound
                      FROM pgpartium.get_latest_partition(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
               )
             , now()
           )
      INTO v_start_timestamp;

    FOR v_partition IN
        WITH dateset AS (
            SELECT "date"
              FROM generate_series(
                       (date_trunc(v_interval_unit, v_start_timestamp) - (p_interval * p_past))
                     , (now() + (p_interval * p_future))
                     , p_interval
                   ) AS "date"
        )
        , current_bounds AS (
            SELECT lower_bound
                 , upper_bound
              FROM pgpartium.get_partition_bounds(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
        )
        , partitions AS (
            -- Range partitions
            SELECT false AS is_default
                 , p_partition_name_template AS name_template
                 , "date" AS lower_bound
                 , ("date" + p_interval) AS upper_bound
                 , format(
                       'FOR VALUES FROM (%1$L) TO (%2$L)'
                     , CASE v_partitioning_details.keys_data_types                                  -- <1: lower_bound>
                         WHEN 'timestamptz'
                           THEN "date"::timestamptz::text
                         WHEN 'timestamp'
                           THEN "date"::timestamp::text
                         WHEN 'date'
                           THEN "date"::date::text
                         WHEN 'int4'
                           THEN (EXTRACT(EPOCH FROM "date")::integer)::text
                         WHEN 'int8'
                           THEN (EXTRACT(EPOCH FROM "date")::bigint * 1000)::text
                         WHEN 'uuid'
                           THEN (
                               overlay(
                                   overlay(
                                       pgpartium.generate_uuid_v7("date")::text
                                       PLACING '0000' FROM 15 FOR 4
                                   )
                                   PLACING '0000-000000000000' FROM 20
                               )
                           )::text
                       END
                     , CASE v_partitioning_details.keys_data_types                                  -- <2: upper_bound>
                         WHEN 'timestamptz'
                           THEN ("date" + p_interval)::timestamptz::text
                         WHEN 'timestamp'
                           THEN ("date" + p_interval)::timestamp::text
                         WHEN 'date'
                           THEN ("date" + p_interval)::date::text
                         WHEN 'int4'
                           THEN (EXTRACT(EPOCH FROM ("date" + p_interval))::integer)::text
                         WHEN 'int8'
                           THEN (EXTRACT(EPOCH FROM ("date" + p_interval))::bigint * 1000)::text
                         WHEN 'uuid'
                           THEN (
                               overlay(
                                   overlay(
                                       pgpartium.generate_uuid_v7("date" + p_interval)::text
                                       PLACING '0000' FROM 15 FOR 4
                                  )
                                  PLACING '0000-000000000000' FROM 20
                               )
                           )::text
                       END
                   ) AS partition_clause
              FROM dateset
            UNION ALL
            -- Default partition
            SELECT true AS is_default
                 , p_default_partition_name_template AS name_template
                 , NULL AS lower_bound
                 , NULL AS upper_bound
                 , 'DEFAULT' AS partition_clause
             WHERE p_create_default
        )
        , filtered AS (
            SELECT is_default
                 , name_template
                 , lower_bound
                 , upper_bound
                 , partition_clause
              FROM partitions
             WHERE NOT is_default
               -- Skip already existing partitions.
               AND NOT EXISTS (
                       SELECT NULL
                         FROM current_bounds
                        WHERE current_bounds.lower_bound = partitions.lower_bound
                          AND current_bounds.upper_bound = partitions.upper_bound
                   )
               -- Optionally skip overlapping partitions.
               AND NOT EXISTS (
                       SELECT NULL
                         FROM current_bounds
                        WHERE p_skip_overlapping
                          AND (current_bounds.lower_bound, current_bounds.upper_bound)
                              OVERLAPS (partitions.lower_bound, partitions.upper_bound)
                   )
               -- Retention filtering.
               AND CASE
                     WHEN p_retention IS NULL
                       THEN true
                     ELSE age(
                            now()
                          , partitions.upper_bound::timestamptz
                        ) < p_retention
                   END
            UNION ALL
            SELECT is_default
                 , name_template
                 , lower_bound
                 , upper_bound
                 , partition_clause
              FROM partitions
             WHERE is_default
               AND NOT EXISTS (
                       SELECT pgpartium.get_default_partition(p_table_schema=>p_table_schema, p_table_name=>p_table_name)
                   )
        )
        , resolved AS (
            SELECT is_default
                 , replace(
                       replace(
                           CASE
                             WHEN is_default
                               THEN name_template
                             ELSE to_char(lower_bound, name_template)
                           END
                         , '{table_name}'
                         , p_table_name
                       )
                     , '{table_schema}'
                     , p_table_schema
                   ) AS partition_name
                 , partition_clause
              FROM filtered
        )
        SELECT is_default
             , partition_name
             , partition_clause
          FROM resolved
         ORDER BY partition_name, is_default -- default last

    LOOP

        -- Get constraint definition.
        SELECT pgpartium.generate_partition_constraints(
               p_parent_table_schema   => p_table_schema
             , p_parent_table_name     => p_table_name
             , p_template_table_schema => p_template_table_schema
             , p_template_table_name   => p_template_table_name
             , p_partition_schema      => v_partition_schema
             , p_partition_name        => v_partition.partition_name
        )
          INTO v_constraints;

        -- Get index create statement.
        SELECT pgpartium.generate_partition_indexes(
               p_parent_table_schema   => p_table_schema
             , p_parent_table_name     => p_table_name
             , p_template_table_schema => p_template_table_schema
             , p_template_table_name   => p_template_table_name
             , p_partition_schema      => v_partition_schema
             , p_partition_name        => v_partition.partition_name
             , p_index_tablespace      => p_index_tablespace
             , p_idempotent_ddl        => p_idempotent_ddl
        )
          INTO v_indexes;

        -- Get create trigger statement.
        SELECT pgpartium.generate_trigger_constraints(
               p_parent_table_schema   => p_table_schema
             , p_parent_table_name     => p_table_name
             , p_template_table_schema => p_template_table_schema
             , p_template_table_name   => p_template_table_name
             , p_partition_schema      => v_partition_schema
             , p_partition_name        => v_partition.partition_name
             , p_idempotent_ddl        => p_idempotent_ddl
        )
          INTO v_triggers;

        -- Get storage parameters.
        SELECT normalized_formatted_overridden_storage_parameters
          FROM pgpartium.normalize_storage_parameters(
               p_relation_schema => p_template_table_schema
             , p_relation_name   => p_template_table_name
             , p_override        => p_partition_storage_parameters
        )
          INTO v_storage_clause;

        -- Add additional new line if needed
        IF v_ddl != '' THEN
            v_ddl := format(E'%1$s\n', v_ddl);
        END IF;

        v_ddl := v_ddl || format(
            E'CREATE TABLE %1$s%2$I.%3$I\n    PARTITION OF %4$I.%5$I%6$s\n    %7$s%8$s%9$s;\n'
          , CASE p_idempotent_ddl                                  -- <1>
              WHEN true
                THEN 'IF NOT EXISTS '
              ELSE ''
            END
          , v_partition_schema                                     -- <2>
          , v_partition.partition_name                             -- <3>
          , p_table_schema                                         -- <4>
          , p_table_name                                           -- <5>
          , COALESCE(E' (\n' || v_constraints || E'\n    )', '')   -- <6>
          , v_partition.partition_clause                           -- <7>
          , E'\n' || v_storage_clause                              -- <8>
          , CASE                                                   -- <9>
              WHEN p_partition_tablespace != 'pg_default'
                THEN format(E'\nTABLESPACE %I', p_partition_tablespace)
              ELSE ''
            END
        );

        v_ddl := COALESCE(v_ddl || E'\n' || v_indexes, v_ddl);
        v_ddl := COALESCE(v_ddl || E'\n' || v_triggers, v_ddl);

    END LOOP;

    IF v_ddl != '' THEN
        RETURN NEXT v_ddl;
    END IF;

    RETURN;

END;
$BODY$;
