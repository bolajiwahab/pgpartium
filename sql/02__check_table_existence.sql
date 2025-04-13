CREATE OR REPLACE FUNCTION pgpartium.table_exists (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$
    SELECT EXISTS (
               SELECT 1
                 FROM pg_catalog.pg_class AS c
                INNER JOIN pg_catalog.pg_namespace AS n
                   ON n.oid = c.relnamespace
                WHERE n.nspname = p_table_schema
                  AND c.relname = p_table_name
           );
$BODY$;
