CREATE OR REPLACE FUNCTION pgpartium.get_partitioning_details (
    table_schema text
  , table_name text
)
RETURNS TABLE (
    number_of_keys integer
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
         , string_agg(format_type(a.atttypid, a.atttypmod), ', ') AS keys_data_types
      FROM pg_catalog.pg_partitioned_table AS p
     INNER JOIN pg_catalog.pg_class AS c
        ON c.oid = p.partrelid
     INNER JOIN pg_catalog.pg_namespace AS n
        ON n.oid = c.relnamespace
     INNER JOIN pg_catalog.pg_attribute AS a
        ON p.partrelid = a.attrelid
       AND a.attnum = ANY(CAST(p.partattrs AS integer[]))
     WHERE n.nspname = table_schema
       AND c.relname = table_name
     GROUP BY n.nspname
            , c.relname
            , p.partnatts
            , p.partstrat, partrelid;
$BODY$;
