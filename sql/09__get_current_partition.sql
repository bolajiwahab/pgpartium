CREATE OR REPLACE FUNCTION pgpartium.get_current_partition (
    table_schema text
  , table_name text
)
RETURNS TABLE (
    partition_schema text
  , partition_name text
  , lower_bound timestamptz
  , upper_bound timestamptz
)
LANGUAGE SQL
AS $BODY$
    SELECT cn.nspname AS partition_schema
         , c.relname AS partition_name
         , CASE keys_data_types
             WHEN 'timestamptz'
               THEN CAST((matches)[1] AS timestamptz)
             WHEN 'timestamp'
               THEN CAST((matches)[1] AS timestamptz)
             WHEN 'date'
               THEN CAST((matches)[1] AS date)
             WHEN 'int4'
               THEN to_timestamp(CAST((matches)[1] AS integer))
             WHEN 'int8'
               THEN to_timestamp(CAST((matches)[1] AS bigint) / 1000)
           END AS lower_bound
         , CASE keys_data_types
             WHEN 'timestamptz'
               THEN CAST((matches)[2] AS timestamptz)
             WHEN 'timestamp'
               THEN CAST((matches)[2] AS timestamptz)
             WHEN 'date'
               THEN CAST((matches)[2] AS date)
             WHEN 'int4'
               THEN to_timestamp(CAST((matches)[2] AS integer))
             WHEN 'int8'
               THEN to_timestamp(CAST((matches)[2] AS bigint) / 1000)
           END AS upper_bound
      FROM pg_catalog.pg_inherits AS i
     INNER JOIN pg_catalog.pg_class AS p
        ON i.inhparent = p.oid
     INNER JOIN pg_catalog.pg_class AS c
        ON i.inhrelid = c.oid
     INNER JOIN pg_catalog.pg_namespace AS pn
        ON pn.oid = p.relnamespace
     INNER JOIN pg_catalog.pg_namespace AS cn
        ON cn.oid = c.relnamespace
     CROSS JOIN regexp_matches(pg_catalog.pg_get_expr(c.relpartbound, c.oid), '\(\''?(.+?)\''?\).+\(\''?(.+?)\''?\)') AS matches
         , LATERAL (SELECT keys_data_types FROM pgpartium.get_partitioning_details(table_schema, table_name)) AS key_data_type
     WHERE c.relispartition
       AND p.relname = table_name
       AND pn.nspname = table_schema
       AND now() >= CASE 'timestamp with time zone'
                      WHEN 'timestamp with time zone'
                        THEN CAST((matches)[1] AS timestamptz)
                      WHEN 'timestamp without time zone'
                        THEN CAST((matches)[1] AS timestamptz)
                      WHEN 'date'
                        THEN CAST((matches)[1] AS date)
                      WHEN 'integer'
                        THEN to_timestamp(CAST((matches)[1] AS integer))
                      WHEN 'bigint'
                        THEN to_timestamp(CAST((matches)[1] AS bigint) / 1000)
                    END
       AND now() < CASE 'timestamp with time zone'
                     WHEN 'timestamp with time zone'
                       THEN CAST((matches)[2] AS timestamptz)
                     WHEN 'timestamp without time zone'
                       THEN CAST((matches)[2] AS timestamptz)
                     WHEN 'date'
                       THEN CAST((matches)[2] AS date)
                     WHEN 'integer'
                       THEN to_timestamp(CAST((matches)[2] AS integer))
                     WHEN 'bigint'
                       THEN to_timestamp(CAST((matches)[2] AS bigint) / 1000)
                   END;
$BODY$;
