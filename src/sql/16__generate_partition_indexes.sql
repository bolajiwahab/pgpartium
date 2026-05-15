CREATE OR REPLACE FUNCTION pgpartium.generate_partition_indexes (
    p_parent_table_schema text
  , p_parent_table_name text
  , p_partition_schema text
  , p_partition_name text
  , p_template_table_schema text
  , p_template_table_name text
  , p_index_tablespace text
  , p_idempotent_ddl boolean
)
RETURNS text
LANGUAGE SQL
AS $BODY$

    WITH template_indexes AS (
        SELECT index_name
             , is_unique_index
             , full_index_definition
             , index_definition_excluding_storage_parameters_and_predicate
             , index_predicate
          FROM pgpartium.get_indexes(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_indexes AS (
        SELECT index_name
             , is_unique_index
             , full_index_definition
             , index_definition_excluding_storage_parameters_and_predicate
             , index_predicate
          FROM pgpartium.get_indexes(p_table_schema=>p_parent_table_schema, p_table_name=>p_parent_table_name)
    )
    , partition_indexes AS (
        SELECT replace(
                   replace(
                       template_indexes.index_name
                     , p_template_table_schema
                     , p_partition_schema
                   )
                 , p_template_table_name
                 , p_partition_name
               ) AS final_index_name
             , CASE
                 WHEN template_indexes.is_unique_index
                   THEN 'UNIQUE INDEX'
                 ELSE 'INDEX'
               END AS index_type
             , template_indexes.is_unique_index
             , template_indexes.index_definition_excluding_storage_parameters_and_predicate
             , template_indexes.index_predicate
          FROM template_indexes
          LEFT JOIN parent_indexes
            ON template_indexes.full_index_definition = parent_indexes.full_index_definition
         WHERE parent_indexes.full_index_definition IS NULL
    )
    SELECT string_agg(
               format(
                   E'%1$s%2$s%3$s;\n'
                 , format(                                                                              --<1: index_create_statement>
                       E'CREATE %1$s %2$s%3$I\n    ON %4$I.%5$I\n %6$s'
                     , partition_indexes.index_type                                                   --<1: index_type>
                     , CASE p_idempotent_ddl                                                          --<2: if_not_exists>
                         WHEN true
                           THEN 'IF NOT EXISTS' || ' '
                         ELSE ''
                       END
                     , partition_indexes.final_index_name                                             --<3: index_name>
                     , p_partition_schema                                                             --<4: table_schema>
                     , p_partition_name                                                               --<5: table_name>
                     , partition_indexes.index_definition_excluding_storage_parameters_and_predicate  --<6: index_definition_excluding_storage_parameters_and_predicate>
                   )
                 , CASE                                                                                 --<2: index_tablespace>
                     WHEN p_index_tablespace != 'pg_default'
                       THEN format(E'\nTABLESPACE %1$I', p_index_tablespace)
                     ELSE ''
                   END
                 , CASE                                                                                 --<3: index_predicate>
                     WHEN partition_indexes.index_predicate <> ''
                       THEN E'\n ' || partition_indexes.index_predicate
                       ELSE partition_indexes.index_predicate
                   END
               )
             , E'\n'
               ORDER BY CASE partition_indexes.is_unique_index
                          WHEN true
                            THEN 0
                          WHEN false
                            THEN 1
                        END
                      , partition_indexes.final_index_name
           )
      FROM partition_indexes;

$BODY$;
