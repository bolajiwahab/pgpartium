CREATE OR REPLACE FUNCTION pgpartium.expire_partitions (
    p_table_schema text
  , p_table_name text
  , p_retention interval DEFAULT NULL
  , p_detach_only boolean DEFAULT false
  , p_detach_first boolean DEFAULT false
  , p_detach_concurrently boolean DEFAULT false
  , p_timezone text DEFAULT 'Etc/UTC'
)
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$

BEGIN

    PERFORM set_config('timezone', p_timezone, true);

    IF NOT pgpartium.table_exists(p_table_schema=>p_table_schema, p_table_name=>p_table_name) THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT pgpartium.is_table_partitioned(p_table_schema=>p_table_schema, p_table_name=>p_table_name) THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF p_detach_only THEN
        RETURN QUERY SELECT string_agg(
            format(
                E'ALTER TABLE %1$I.%2$I\n    DETACH PARTITION %3$I.%4$I%5$s;\n'
              , p_table_schema                                                   -- <1>
              , p_table_name                                                     -- <2>
              , partition_schema                                                 -- <3>
              , partition_name                                                   -- <4>
              , CASE WHEN p_detach_concurrently THEN ' CONCURRENTLY' ELSE '' END -- <5>
            ),
            E'\n'
            ORDER BY age DESC
        )
          FROM pgpartium.get_expired_partitions(p_table_schema=>p_table_schema, p_table_name=>p_table_name, p_retention=>p_retention)
        HAVING COUNT(*) > 0;

        RETURN;

    END IF;

    IF p_detach_first THEN
        RETURN QUERY SELECT string_agg(
            format(
                E'ALTER TABLE %1$I.%2$I\n    DETACH PARTITION %3$I.%4$I%5$s;\n\nDROP TABLE %3$I.%4$I;\n'
              , p_table_schema                                                   -- <1>
              , p_table_name                                                     -- <2>
              , partition_schema                                                 -- <3>
              , partition_name                                                   -- <4>
              , CASE WHEN p_detach_concurrently THEN ' CONCURRENTLY' ELSE '' END -- <5>
            ),
            E'\n'
            ORDER BY age DESC
        )
          FROM pgpartium.get_expired_partitions(p_table_schema=>p_table_schema, p_table_name=>p_table_name, p_retention=>p_retention)
        HAVING COUNT(*) > 0;

        RETURN;

    END IF;

    RETURN QUERY SELECT string_agg(
        format(
            E'DROP TABLE %1$I.%2$I;\n'
          , partition_schema          -- <1>
          , partition_name            -- <2>
        ),
        E'\n'
        ORDER BY age DESC
    )
      FROM pgpartium.get_expired_partitions(p_table_schema=>p_table_schema, p_table_name=>p_table_name, p_retention=>p_retention)
    HAVING COUNT(*) > 0;

    RETURN;

END;

$BODY$;
