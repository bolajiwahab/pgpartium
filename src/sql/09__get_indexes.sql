CREATE OR REPLACE FUNCTION pgpartium.get_indexes (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    index_name name
  , is_unique_index boolean
  , full_index_definition text
  , index_definition_excluding_storage_parameters_and_predicate text
  , index_storage_parameters text
  , index_predicate text
)
LANGUAGE SQL
AS $BODY$
    WITH indexes AS (
        SELECT ix.relname AS index_name
             , indisunique AS is_unique_index
             , substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE) FROM 'USING .*') AS full_index_definition
             , (pgpartium.normalize_storage_parameters(inp.nspname, ix.relname)).normalized_current_storage_parameters AS index_storage_parameters
             , COALESCE('WHERE ' || pg_catalog.pg_get_expr(i.indpred, i.indrelid, TRUE), '') AS index_predicate
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS r
            ON n.oid = r.relnamespace
         INNER JOIN pg_catalog.pg_index AS i
            ON r.oid = i.indrelid AND i.indisvalid
         INNER JOIN pg_catalog.pg_class AS ix
            ON i.indexrelid = ix.oid
         INNER JOIN pg_catalog.pg_namespace AS inp
            ON ix.relnamespace = inp.oid
          LEFT JOIN pg_catalog.pg_constraint AS c
            ON i.indexrelid = c.conindid
         WHERE n.nspname = p_table_schema
           AND r.relname = p_table_name
           AND c.conindid IS NULL
   )
    SELECT index_name
         , is_unique_index
         , full_index_definition
         , rtrim(
               replace(
                   replace(
                       full_index_definition
                     , COALESCE(index_storage_parameters, '')
                     , ''
                   )
                 , index_predicate
                 , ''
               )
           ) AS index_definition_excluding_storage_parameters_and_predicate
         , index_storage_parameters
         , index_predicate
      FROM indexes;
$BODY$;
