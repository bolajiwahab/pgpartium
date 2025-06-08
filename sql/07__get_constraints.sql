CREATE OR REPLACE FUNCTION pgpartium.get_constraints (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    constraint_name name
  , constraint_type "char"
  , constraint_definition text
)
LANGUAGE SQL
AS $BODY$
    SELECT c.conname
         , c.contype
         , pg_catalog.pg_get_constraintdef(c.oid, TRUE) AS constraint_definition
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS t
        ON n.oid = t.relnamespace
     INNER JOIN pg_catalog.pg_constraint AS c
        ON t.oid = c.conrelid
      LEFT JOIN LATERAL (
                            SELECT string_agg(attname, ', ' ORDER BY a.attnum) AS columns
                              FROM pg_catalog.pg_attribute AS a
                             WHERE a.attrelid = c.conrelid
                               AND a.attnum = ANY(c.conkey)
                        ) AS a
        ON TRUE
     WHERE n.nspname = p_table_schema
       AND t.relname = p_table_name;
$BODY$;
