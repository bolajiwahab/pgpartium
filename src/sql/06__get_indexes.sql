CREATE OR REPLACE FUNCTION pgpartix.get_indexes (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    index_name text
  , is_unique_index boolean
  , index_type text
  , index_keys text
  , ordinal integer
  , index_definition text
  , index_tablespace text
)
LANGUAGE SQL
AS $BODY$


    /*
    * @param p_table_schema: The schema of the table.
    * @param p_table_name: The name of the table.

    * @return index_name: The name of the index.
    * @return is_unique_index: Whether the index is unique.
    * @return index_keys: The keys of the index.
    * @return ordinal: The ordinal of the index.
    * @return index_definition: The definition of the index.
    * @return index_tablespace: The tablespace of the index.
    */

    WITH indexes AS (
        SELECT ix.oid AS index_oid
             , ix.relname AS index_name
             , indisunique AS is_unique_index
             , am.amname AS index_type
             , string_agg(
                   COALESCE(a.attname, 'expr')
                 , '_'
                   ORDER BY u.ordinality
               ) AS index_keys
             , substring(pg_catalog.pg_get_indexdef(i.indexrelid, 0, TRUE) FROM 'USING .*') AS index_definition
             , pgpartix.get_relation_tablespace(
                   p_relation_schema => inp.nspname
                 , p_relation_name => ix.relname
               ) AS index_tablespace
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS r
            ON n.oid = r.relnamespace
         INNER JOIN pg_catalog.pg_index AS i
            ON r.oid = i.indrelid AND i.indisvalid
         INNER JOIN pg_catalog.pg_class AS ix
            ON i.indexrelid = ix.oid
         INNER JOIN pg_catalog.pg_am AS am
            ON ix.relam = am.oid
         INNER JOIN pg_catalog.pg_namespace AS inp
            ON ix.relnamespace = inp.oid
          LEFT JOIN pg_catalog.pg_constraint AS c
            ON i.indexrelid = c.conindid
         CROSS JOIN LATERAL unnest(i.indkey::int2[])
          WITH ORDINALITY AS u(attnum, ordinality)
          LEFT JOIN pg_catalog.pg_attribute a
            ON a.attrelid = r.oid
           AND a.attnum = u.attnum
         WHERE n.nspname = p_table_schema
           AND r.relname = p_table_name
           AND c.conindid IS NULL
         GROUP BY inp.nspname
             , ix.oid
             , ix.relname
             , i.indisunique
             , am.amname
             , i.indpred
             , i.indrelid
             , i.indexrelid
   )
    SELECT index_name
         , is_unique_index
         , index_type
         , index_keys
         , row_number() OVER (PARTITION BY index_keys ORDER BY index_oid) - 1 AS ordinal
         , index_definition
         , index_tablespace
      FROM indexes;
$BODY$;
