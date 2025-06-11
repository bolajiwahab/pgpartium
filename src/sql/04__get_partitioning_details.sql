CREATE OR REPLACE FUNCTION pgpartium.get_partitioning_details (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    number_of_keys smallint
  , strategy text
  , keys text
  , keys_data_types text
)
LANGUAGE SQL
AS $BODY$
    SELECT p.partnatts AS number_of_keys
         , CASE p.partstrat
             WHEN 'r'
               THEN 'RANGE'
             WHEN 'l'
               THEN 'LIST'
             WHEN 'h'
               THEN 'HASH'
           END AS strategy
         , string_agg(a.attname, ', ') AS keys
         , string_agg(t.typname, ', ') AS keys_data_types
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS c
        ON n.oid = c.relnamespace
     INNER JOIN pg_catalog.pg_partitioned_table AS p
        ON c.oid = p.partrelid
     INNER JOIN pg_catalog.pg_attribute AS a
        ON p.partrelid = a.attrelid
       AND a.attnum = ANY(CAST(p.partattrs AS integer[]))
     INNER JOIN pg_catalog.pg_type AS t
        ON a.atttypid = t.oid
     WHERE n.nspname = p_table_schema
       AND c.relname = p_table_name
     GROUP BY n.nspname
            , c.relname
            , p.partrelid
            , p.partnatts
            , p.partstrat;
$BODY$;
