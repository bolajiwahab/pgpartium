CREATE OR REPLACE FUNCTION pgpartium.get_default_partition (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    partition_schema name
  , partition_name name
)
LANGUAGE SQL
AS $BODY$
    SELECT cn.nspname AS partition_schema
         , c.relname AS partition_name
      FROM pg_catalog.pg_namespace AS pn
     INNER JOIN pg_catalog.pg_class AS p
        ON pn.oid = p.relnamespace
     INNER JOIN pg_catalog.pg_inherits AS i
        ON p.oid = i.inhparent
     INNER JOIN pg_catalog.pg_class AS c
        ON i.inhrelid = c.oid
     INNER JOIN pg_catalog.pg_namespace AS cn
        ON c.relnamespace = cn.oid
     WHERE pn.nspname = p_table_schema
       AND p.relname = p_table_name
       AND c.relispartition
       AND pg_catalog.pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT';
$BODY$;
