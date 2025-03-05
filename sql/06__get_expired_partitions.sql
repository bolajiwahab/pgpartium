CREATE OR REPLACE FUNCTION pgpartium.get_expired_partitions (
    table_schema text
  , table_name text
  , key_data_type text
  , retention_period interval
)
RETURNS TABLE (
    partition_schema text
  , partition_name text
  , lower_bound text
  , upper_bound text
  , age interval
)
LANGUAGE SQL
AS $BODY$
    SELECT cn.nspname AS partition_schema
         , c.relname AS partition_name
         , (matches)[1] AS lower_bound
         , (matches)[2] AS upper_bound
         , CASE key_data_type
             WHEN 'timestamp with time zone'
               THEN age(now(), CAST((matches)[2] AS timestamptz))
             WHEN 'timestamp without time zone'
               THEN age(now(), CAST((matches)[2] AS timestamptz))
             WHEN 'date'
               THEN age(now(), CAST((matches)[2] AS date))
             WHEN 'integer'
               THEN age(now(), to_timestamp(CAST((matches)[2] AS integer)))
             WHEN 'bigint'
               THEN age(now(), to_timestamp(CAST((matches)[2] AS bigint) / 1000))
           END AS age
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
     WHERE c.relispartition
       AND p.relname = table_name
       AND pn.nspname = table_schema
       AND CASE key_data_type
             WHEN 'timestamp with time zone'
               THEN age(now(), CAST((matches)[2] AS timestamptz))
             WHEN 'timestamp without time zone'
               THEN age(now(), CAST((matches)[2] AS timestamptz))
             WHEN 'date'
               THEN age(now(), CAST((matches)[2] AS date))
             WHEN 'integer'
               THEN age(now(), to_timestamp(CAST((matches)[2] AS integer)))
             WHEN 'bigint'
               THEN age(now(), to_timestamp(CAST((matches)[2] AS bigint) / 1000))
           END > retention_period
     ORDER BY age DESC;
$BODY$;
