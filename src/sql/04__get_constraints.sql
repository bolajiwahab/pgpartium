CREATE OR REPLACE FUNCTION pgpartium.get_constraints (
    p_table_schema text
  , p_table_name text
  , p_constraint_type_map jsonb DEFAULT NULL
)
RETURNS TABLE (
    constraint_name name
  , constraint_type "char"
  , constraint_type_name text
  , constraint_keys text
  , ordinal integer
  , constraint_definition text
)
LANGUAGE SQL
AS $BODY$

    WITH constraints AS (
        SELECT c.oid AS constraint_oid
             , c.conname AS constraint_name
             , c.contype AS constraint_type
             , COALESCE(
                   p_constraint_type_map ->> c.contype
                 , CASE c.contype
                     WHEN 'p' THEN 'pkey'
                     WHEN 'u' THEN 'key'
                     WHEN 'f' THEN 'fkey'
                     WHEN 'c' THEN 'check'
                     WHEN 'x' THEN 'excl'
                   END
               ) AS constraint_type_name
             , COALESCE(
                   string_agg(
                       COALESCE(
                           a.attname
                         , 'expr'
                       )
                     , '_'
                       ORDER BY u.ordinality
                   )
                 , 'expr'
               ) AS constraint_keys
             , pg_catalog.pg_get_constraintdef(c.oid, TRUE) AS constraint_definition
          FROM pg_catalog.pg_namespace AS n
          JOIN pg_catalog.pg_class AS t
            ON n.oid = t.relnamespace
          JOIN pg_catalog.pg_constraint AS c
            ON t.oid = c.conrelid
          LEFT JOIN LATERAL unnest(c.conkey::int2[])
          WITH ORDINALITY AS u(attnum, ordinality)
            ON TRUE
          LEFT JOIN pg_catalog.pg_attribute AS a
            ON a.attrelid = c.conrelid
           AND a.attnum = u.attnum
         WHERE n.nspname = p_table_schema
           AND t.relname = p_table_name
           -- Exclude NOT NULL constraints
           AND c.contype <> 'n'
         GROUP BY c.conname
                , c.contype
                , c.oid
    )
    SELECT constraint_name
         , constraint_type
         , constraint_type_name
         , constraint_keys
         , row_number() OVER (
               PARTITION BY constraint_type, constraint_keys
               ORDER BY constraint_oid
           ) - 1 AS ordinal
         , constraint_definition
      FROM constraints;
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.get_not_null_constraints (
    p_table_schema text,
    p_table_name text
)
RETURNS TABLE (
    column_name text,
    constraint_definition text
)
LANGUAGE SQL
STRICT
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
