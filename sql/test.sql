CREATE TEMPORARY TABLE current_bounds ON COMMIT DROP AS
SELECT CASE _partitioning_details.keys_data_types
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
       END AS lowerbound
     , CASE _partitioning_details.keys_data_types
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
       END AS upperbound
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
--    AND c.relkind = 'r'
   AND p.relname = table_name
   AND pn.nspname = table_schema;
