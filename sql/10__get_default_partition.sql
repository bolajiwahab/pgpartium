CREATE OR REPLACE FUNCTION pgpartium.get_default_partition (
    table_schema text
  , table_name text
)
RETURNS TABLE (
    partition_schema text
  , partition_name text
)
LANGUAGE SQL
AS $BODY$
    SELECT cn.nspname AS partition_schema
         , c.relname AS partition_name
      FROM pg_catalog.pg_inherits AS i
     INNER JOIN pg_catalog.pg_class AS p
        ON i.inhparent = p.oid
     INNER JOIN pg_catalog.pg_class AS c
        ON i.inhrelid = c.oid
     INNER JOIN pg_catalog.pg_namespace AS pn
        ON pn.oid = p.relnamespace
     INNER JOIN pg_catalog.pg_namespace AS cn
        ON cn.oid = c.relnamespace
     WHERE c.relispartition
       AND p.relname = table_name
       AND pn.nspname = table_schema
       AND pg_catalog.pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT';
$BODY$;
