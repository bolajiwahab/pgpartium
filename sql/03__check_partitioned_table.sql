CREATE OR REPLACE FUNCTION pgpartium.is_table_partitioned (
    table_schema text
  , table_name text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$
    SELECT EXISTS (
               SELECT 1
                 FROM pg_catalog.pg_class AS c
                INNER JOIN pg_catalog.pg_namespace AS n
                   ON n.oid = c.relnamespace
                WHERE n.nspname = table_schema
                  AND c.relname = table_name
                  AND c.relkind = 'p'
           );
$BODY$;
