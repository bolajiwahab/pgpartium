CREATE OR REPLACE FUNCTION pgpartium.get_indexes (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    index_name name
  , is_unique_index boolean
  , full_index_definition text
  , index_definition_without_predicate text
  , index_predicate text
)
LANGUAGE SQL
AS $BODY$
    WITH indexes AS (
        SELECT ix.relname AS index_name
             , indisunique AS is_unique_index
             , substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE) FROM 'USING .*') AS full_index_definition
             , COALESCE('WHERE ' || pg_catalog.pg_get_expr(i.indpred, i.indrelid, TRUE), '') AS index_predicate
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS t
            ON n.oid = t.relnamespace
         INNER JOIN pg_catalog.pg_index AS i
            ON t.oid = i.indrelid AND i.indisvalid
         INNER JOIN pg_catalog.pg_class AS ix
            ON i.indexrelid = ix.oid
          LEFT JOIN pg_catalog.pg_constraint AS c
            ON i.indexrelid = c.conindid
         WHERE n.nspname = p_table_schema
           AND t.relname = p_table_name
           AND c.conindid IS NULL
   )
    SELECT index_name
         , is_unique_index
         , full_index_definition
         , rtrim(replace(full_index_definition, index_predicate, '')) AS index_definition_without_predicate
         , index_predicate
      FROM indexes;
$BODY$;
