CREATE OR REPLACE FUNCTION pgpartium.get_not_null_constraints (
    p_table_schema text,
    p_table_name text
)
RETURNS TABLE (
    column_name text,
    constraint_definition text
)
LANGUAGE SQL
STABLE
AS $BODY$

    SELECT a.attname AS column_name
         , pg_catalog.pg_get_constraintdef(
               c.oid,
               TRUE
           ) AS constraint_definition
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS t
        ON n.oid = t.relnamespace
     INNER JOIN pg_catalog.pg_constraint AS c
        ON t.oid = c.conrelid
     INNER JOIN pg_catalog.pg_attribute AS a
        ON a.attrelid = t.oid
       AND a.attnum = c.conkey[1]
     WHERE n.nspname = p_table_schema
       AND t.relname = p_table_name
       AND c.contype = 'n';

$BODY$;
