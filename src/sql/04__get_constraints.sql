CREATE OR REPLACE FUNCTION pgpartix.get_constraints (
    p_table_schema text
  , p_table_name text
  , p_constraint_name_templates jsonb DEFAULT NULL
)
RETURNS TABLE (
    constraint_name text
  , constraint_type "char"
  , constraint_name_template text
  , constraint_keys text
  , ordinal integer
  , constraint_definition text
)
LANGUAGE SQL
AS $BODY$

/*
    * @param p_table_schema (text): The schema of the table.
    * @param p_table_name (text): The name of the table.
    * @param p_constraint_name_templates (jsonb): A JSONB object containing templates for constraint names.
        The keys are constraint types ('primary_key', 'unique_key', 'foreign_key', 'check', 'exclusion')
        and the values are the corresponding templates. A generic template can also be specified with `template`
        which will be used for every constraint type.
        If a template is not provided for a constraint type and no generic template, a default template will be used.

    * @return constraint_name (text): The name of the constraint.
    * @return constraint_type ("char"): The type of the constraint
        ('p' for primary key, 'u' for unique key, 'f' for foreign key, 'c' for check, 'x' for exclusion).
    * @return constraint_name_template (text): The template used to generate the constraint name.
    * @return constraint_keys (text): The keys of the constraint, concatenated with underscores.
    * @return ordinal (integer): The ordinal number of the constraint, when there are two or more constraints with the same definition.
    * @return constraint_definition (text): The definition of the constraint.
*/

    WITH constraints AS (
        SELECT c.oid AS constraint_oid
             , c.conname AS constraint_name
             , c.contype AS constraint_type
             , COALESCE(
                   p_constraint_name_templates ->> CASE c.contype
                       WHEN 'p' THEN 'primary_key'
                       WHEN 'u' THEN 'unique_key'
                       WHEN 'f' THEN 'foreign_key'
                       WHEN 'c' THEN 'check'
                       WHEN 'x' THEN 'exclusion'
                   END
                 , p_constraint_name_templates ->> 'template'
                 , CASE c.contype
                     WHEN 'p' THEN '{partition_name}_pkey'
                     WHEN 'u' THEN '{partition_name}_{constraint_keys}_key'
                     WHEN 'f' THEN '{partition_name}_{constraint_keys}_fkey'
                     WHEN 'c' THEN '{partition_name}_{constraint_keys}_check'
                     WHEN 'x' THEN '{partition_name}_{constraint_keys}_excl'
                   END
               ) AS constraint_name_template
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
         , constraint_name_template
         , constraint_keys
         , row_number() OVER (
               PARTITION BY constraint_type, constraint_keys
               ORDER BY constraint_oid
           ) - 1 AS ordinal
         , constraint_definition
      FROM constraints;
$BODY$;
