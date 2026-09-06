CREATE OR REPLACE FUNCTION pgpartix.expire_partitions (
    p_table_schema text
  , p_table_name text
  , p_retention interval DEFAULT NULL
  , p_detach_only boolean DEFAULT FALSE
  , p_detach_first boolean DEFAULT FALSE
  , p_detach_concurrently boolean DEFAULT FALSE
  , p_timezone text DEFAULT 'Etc/UTC'
  , p_idempotent boolean DEFAULT FALSE
)
RETURNS SETOF text
LANGUAGE plpgsql
AS $BODY$

/*
    * @param p_table_schema (text): The schema of the partitioned table.
    * @param p_table_name (text): The name of the partitioned table.
    * @param p_retention (interval): The retention period for partitions.
        Partitions older than this interval will be considered expired.
    * @param p_detach_only (boolean): If TRUE, expired partitions will be detached from the parent table
        instead of being dropped. Default is FALSE.
    * @param p_detach_first (boolean): If TRUE, expired partitions will be detached from the parent table
        before being dropped. Default is FALSE.
    * @param p_detach_concurrently (boolean): If TRUE, expired partitions will be detached concurrently.
        This option is only applicable if p_detach_only or p_detach_first is TRUE. Default is FALSE.
    * @param p_timezone (text): The timezone to use for timestamp calculations. Default is 'Etc/UTC'.
    * @param p_idempotent (boolean): If TRUE, the generated SQL statements will include "IF EXISTS"
        to avoid errors if the partition does not exist. Default is FALSE.

    * @return SETOF text: A set of SQL statements to detach or drop the expired partitions.
*/

BEGIN

    PERFORM set_config('timezone', p_timezone, TRUE);

    IF NOT pgpartix.table_exists(p_table_schema => p_table_schema, p_table_name => p_table_name) THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT pgpartix.is_table_partitioned(p_table_schema => p_table_schema, p_table_name => p_table_name) THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    RETURN QUERY
    SELECT string_agg(
               CASE
                 WHEN p_detach_only
                   THEN format(
                            E'ALTER TABLE %1$s%2$I.%3$I\n    DETACH PARTITION %4$I.%5$I%6$s;\n'
                          , CASE p_idempotent                                     -- <1>
                              WHEN TRUE
                                THEN 'IF EXISTS '
                              ELSE ''
                            END
                          , p_table_schema                                         -- <2>
                          , p_table_name                                           -- <3>
                          , partition_schema                                       -- <4>
                          , partition_name                                         -- <5>
                          , CASE                                                   -- <6>
                              WHEN p_detach_concurrently
                                THEN ' CONCURRENTLY'
                              ELSE ''
                            END
                        )
                 WHEN p_detach_first
                   THEN format(
                            E'ALTER TABLE %1$s%2$I.%3$I\n    DETACH PARTITION %4$I.%5$I%6$s;\n\nDROP TABLE %1$s%4$I.%5$I;\n'
                          , CASE p_idempotent                                      -- <1>
                              WHEN TRUE
                                THEN 'IF EXISTS '
                              ELSE ''
                            END
                          , p_table_schema                                         -- <2>
                          , p_table_name
                          , partition_schema                                       -- <3>
                          , partition_name                                         -- <4>
                          , CASE                                                   -- <5>
                              WHEN p_detach_concurrently
                                THEN ' CONCURRENTLY'
                              ELSE ''
                            END
                        )
                 ELSE format(
                          E'DROP TABLE %1$s%2$I.%3$I;\n'
                        , CASE p_idempotent                                   -- <1>
                            WHEN TRUE
                              THEN 'IF EXISTS '
                            ELSE ''
                          END
                        , partition_schema                                       -- <2>
                        , partition_name                                         -- <3>
                      )
               END,
               E'\n'
               ORDER BY age DESC
           )
      FROM pgpartix.get_expired_partitions(
               p_table_schema => p_table_schema
             , p_table_name   => p_table_name
             , p_retention    => p_retention
           )
    HAVING COUNT(*) > 0;

END;

$BODY$;
