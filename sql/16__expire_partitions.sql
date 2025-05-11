CREATE OR REPLACE FUNCTION pgpartium.expire_partitions (
    p_table_schema text
  , p_table_name text
  , p_retention interval = '-1'
  , p_detach_only boolean = false
  , p_detach_first boolean = false
  , p_detach_concurrently boolean = false
  , p_timezone text = 'Etc/UTC'
)
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_parent_exists            boolean;
    v_is_parent_partitioned    boolean;

BEGIN

    PERFORM set_config('timezone', p_timezone, true);
    PERFORM set_config('client_min_messages', 'warning', true);

    v_parent_exists := pgpartium.table_exists(p_table_schema=>p_table_schema, p_table_name=>p_table_name);
    v_is_parent_partitioned := pgpartium.is_table_partitioned(p_table_schema=>p_table_schema, p_table_name=>p_table_name);

    IF NOT v_parent_exists THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT v_is_parent_partitioned THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF p_detach_only THEN
        RETURN QUERY SELECT string_agg(
            format(
                E'ALTER TABLE %1$I.%2$I\n    DETACH PARTITION %3$I.%4$I%5$s;\n',
/*
This alignment is needed to have the right indentation in the generated migration scripts.
We could use new lines characters instead for the alignment, but that would require escaping with `E`
which does not work with dollar quoting.
*/
-- $SQL$ALTER TABLE %1$I.%2$I
--     DETACH PARTITION %3$I.%4$I%5$s;
-- $SQL$,
                p_table_schema                                                   -- <1>
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
/*
This alignment is needed to have the right indentation in the generated migration scripts.
We could use new lines characters instead for the alignment, but that would require escaping with `E`
which does not work with dollar quoting.
*/
$SQL$ALTER TABLE %1$I.%2$I
    DETACH PARTITION %3$I.%4$I%5$s;

DROP TABLE %3$I.%4$I;
$SQL$,
                p_table_schema                                                   -- <1>
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

/*
This alignment is needed to have the right indentation in the generated migration scripts.
We could use new lines characters instead for the alignment, but that would require escaping with `E`
which does not work with dollar quoting.
*/
$SQL$DROP TABLE %1$I.%2$I;
$SQL$,
            partition_schema          -- <1>
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
