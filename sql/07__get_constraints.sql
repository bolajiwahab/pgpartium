CREATE OR REPLACE FUNCTION pgpartium.get_constraints (
    table_schema text
  , table_name text
)
RETURNS TABLE (
    columns text
  , constraint_definition text
)
LANGUAGE SQL
AS $BODY$
    SELECT a.columns
         , pg_catalog.pg_get_constraintdef(c.oid) AS constraint_definition
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS p
        ON n.oid = p.relnamespace
     INNER JOIN pg_catalog.pg_constraint AS c
        ON c.conrelid = p.oid
      LEFT JOIN LATERAL (
                            SELECT string_agg(attname, ', ' ORDER BY a.attnum) AS columns
                              FROM pg_catalog.pg_attribute AS a
                             WHERE a.attrelid = c.conrelid
                               AND a.attnum = ANY(c.conkey)
                        ) AS a
        ON TRUE
     WHERE n.nspname = table_schema
       AND p.relname = table_name
     ORDER BY c.oid;
$BODY$;
