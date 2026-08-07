CREATE OR REPLACE FUNCTION pgpartium.generate_partition_constraints (
    p_parent_table_schema text
  , p_parent_table_name text
  , p_partition_schema text
  , p_partition_name text
  , p_template_table_schema text DEFAULT NULL
  , p_template_table_name text DEFAULT NULL
  , p_constraint_name_templates jsonb DEFAULT NULL
)
RETURNS text
LANGUAGE SQL
AS $BODY$

    WITH template_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_name_template
             , constraint_keys
             , ordinal::text AS ordinal
             , constraint_definition
          FROM pgpartium.get_constraints(
                   p_table_schema => p_template_table_schema
                 , p_table_name => p_template_table_name
                 , p_constraint_name_templates => p_constraint_name_templates
               )
    )
    , parent_constraints AS (
        SELECT constraint_definition
          FROM pgpartium.get_constraints(p_table_schema => p_parent_table_schema, p_table_name => p_parent_table_name)
    )
    , partition_constraints AS (
        SELECT pgpartium.render_template(
                   template_constraints.constraint_name_template
                 , jsonb_build_object(
                       '{parent_table_schema}', p_parent_table_schema
                     , '{parent_table_name}', p_parent_table_name
                     , '{partition_schema}', p_partition_schema
                     , '{partition_name}', p_partition_name
                     , '{constraint_keys}', template_constraints.constraint_keys
                     , '{constraint_suffix}', CASE template_constraints.constraint_type
                           WHEN 'p' THEN 'pkey'
                           WHEN 'u' THEN 'key'
                           WHEN 'f' THEN 'fkey'
                           WHEN 'c' THEN 'check'
                           WHEN 'x' THEN 'excl'
                       END
                     , '{ordinal}', CASE template_constraints.ordinal
                                      WHEN '0'
                                        THEN ''
                                      ELSE template_constraints.ordinal
                                    END
                   )
               ) AS final_constraint_name
             , template_constraints.constraint_type
             , template_constraints.constraint_definition
          FROM template_constraints
          LEFT JOIN parent_constraints
            ON template_constraints.constraint_definition = parent_constraints.constraint_definition
         WHERE parent_constraints.constraint_definition IS NULL
    )
    SELECT string_agg(
               format(
                   '        CONSTRAINT %1$s%2$s'
                --  , partition_constraints.final_constraint_name              --<1: final_constraint_name>
                   -- We are using CASE here instead of COALESCE because we need to escape the identifier only if there is
                   -- a final_constraint_name.
                 , CASE                                                     --<1: final_constraint_name>
                     WHEN partition_constraints.final_constraint_name IS NULL
                       THEN ''
                     ELSE format('%1$I ', partition_constraints.final_constraint_name)
                   END
                 , partition_constraints.constraint_definition              --<2: constraint_definition>
               )
             , E',\n'
               ORDER BY CASE partition_constraints.constraint_type
                          WHEN 'p'  -- primary key
                            THEN 0
                          WHEN 'u'  -- unique key
                            THEN 1
                          ELSE 2    -- other
                        END
                      , partition_constraints.final_constraint_name
           )
      FROM partition_constraints;

$BODY$;
