CREATE OR REPLACE FUNCTION pgpartium.get_indexes (
    table_schema text
  , table_name text
)
RETURNS TABLE (
    index_name text
  , index_definition text
  , index_create_statement text
)
LANGUAGE SQL
AS $BODY$
    SELECT ix.relname AS index_name
         , substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE) FROM 'USING .*') AS index_definition
         , pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE) AS index_create_statement
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS t
        ON n.oid = t.relnamespace
     INNER JOIN pg_catalog.pg_index AS i
        ON i.indrelid = t.oid
     INNER JOIN pg_catalog.pg_class AS ix
        ON i.indexrelid = ix.oid
      LEFT JOIN pg_catalog.pg_constraint AS c
        ON c.conindid = i.indexrelid
     WHERE n.nspname = table_schema
       AND t.relname = table_name
       AND c.conindid IS NULL;
$BODY$;
