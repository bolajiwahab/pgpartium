CREATE OR REPLACE FUNCTION pgpartium.generate_partition_constraints_ddl (
    p_parent_table_schema text
  , p_parent_table_name text
  , p_partition_schema text
  , p_partition_name text
  , p_template_table_schema text
  , p_template_table_name text
)
RETURNS text
LANGUAGE SQL
AS $BODY$

    WITH template_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_constraints AS (
        SELECT constraint_name
             , constraint_type
             , constraint_definition
          FROM pgpartium.get_constraints(p_table_schema=>p_parent_table_schema, p_table_name=>p_parent_table_name)
    )
    , partition_constraints AS (
        SELECT replace(
                   replace(
                       template_constraints.constraint_name
                     , p_template_table_schema
                     , p_partition_schema
                   )
                 , p_template_table_name
                 , p_partition_name
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
                   '        CONSTRAINT %1$I %2$s'
                 , partition_constraints.final_constraint_name              --<1: final_constraint_name>
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
