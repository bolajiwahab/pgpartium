CREATE OR REPLACE FUNCTION pgpartix.generate_partition_triggers (
    p_parent_table_schema text
  , p_parent_table_name text
  , p_partition_schema text
  , p_partition_name text
  , p_template_table_schema text
  , p_template_table_name text
  , p_trigger_name_template text DEFAULT NULL
  , p_idempotent boolean DEFAULT FALSE
)
RETURNS text
LANGUAGE SQL
AS $BODY$

/*
    * @param p_parent_table_schema (text): The schema of the parent partitioned table.
    * @param p_parent_table_name (text): The name of the parent partitioned table.
    * @param p_partition_schema (text): The schema of the partition.
    * @param p_partition_name (text): The name of the partition.
    * @param p_template_table_schema (text): The schema of the template table.
    * @param p_template_table_name (text): The name of the template table.
    * @param p_trigger_name_template (text): A template for generating trigger names.
        The placeholders in the template will be replaced with the corresponding values for each trigger.
    * @param p_idempotent (boolean): If TRUE, the generated trigger creation statements will
        include "OR REPLACE" to avoid errors if the trigger already exists.

    * @return text: A string containing the SQL statements to create the triggers for the partition.
*/

    WITH template_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , trigger_function_schema
             , trigger_function_name
             , event_timing
             , trigger_event
             , ordinal::text AS ordinal
             , trigger_body
          FROM pgpartix.get_triggers(p_table_schema => p_template_table_schema, p_table_name => p_template_table_name)
    )
    , parent_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , trigger_function_schema
             , trigger_function_name
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartix.get_triggers(p_table_schema => p_parent_table_schema, p_table_name => p_parent_table_name)
    )
    , partition_triggers AS (
        SELECT pgpartix.render_template(
                   p_template => p_trigger_name_template
                 , p_values => jsonb_build_object(
                       '{parent_table_schema}', p_parent_table_schema,
                       '{parent_table_name}',   p_parent_table_name,
                       '{partition_schema}',    p_partition_schema,
                       '{partition_name}',      p_partition_name,
                       '{trigger_event}',       lower(template_triggers.trigger_event),
                       '{event_timing}',        lower(template_triggers.event_timing),
                       '{trigger_function_schema}', template_triggers.trigger_function_schema,
                       '{trigger_function_name}', template_triggers.trigger_function_name,
                       '{ordinal}',             CASE template_triggers.ordinal
                                                   WHEN '0'
                                                     THEN ''
                                                   ELSE template_triggers.ordinal
                                                 END
                       )
               ) AS final_trigger_name
             , CASE
                 WHEN template_triggers.is_constraint_trigger
                   THEN 'CONSTRAINT TRIGGER'
                  ELSE 'TRIGGER'
               END AS trigger_type
             , template_triggers.is_trigger_enabled
             , template_triggers.is_constraint_trigger
             , template_triggers.event_timing
             , template_triggers.trigger_event
             , template_triggers.trigger_body
          FROM template_triggers
          LEFT JOIN parent_triggers
            ON template_triggers.is_constraint_trigger = parent_triggers.is_constraint_trigger
           AND template_triggers.event_timing = parent_triggers.event_timing
           AND template_triggers.trigger_event = parent_triggers.trigger_event
           AND template_triggers.trigger_body = parent_triggers.trigger_body
         WHERE parent_triggers.trigger_body IS NULL
    )
    SELECT string_agg(
        format(
           E'CREATE %1$s%2$s %3$I %4$s %5$s\n    ON %6$I.%7$I\n   %8$s;\n%9$s'
         , CASE p_idempotent                                    --<1: idempotence>
             WHEN TRUE
               THEN 'OR REPLACE' || ' '
             ELSE ''
           END
         , partition_triggers.trigger_type                      --<2: trigger_type>
         , partition_triggers.final_trigger_name                --<3: trigger_name>
         , partition_triggers.event_timing                      --<4: event_timing>
         , partition_triggers.trigger_event                     --<5: trigger_event>
         , p_partition_schema                                   --<6: partition_schema>
         , p_partition_name                                     --<7: partition_name>
         , partition_triggers.trigger_body                      --<8: trigger_body>
         , CASE                                                 --<9: disable_trigger>
             WHEN NOT partition_triggers.is_trigger_enabled
               THEN format(
                        E'\nALTER TABLE %1$I.%2$I\n    DISABLE TRIGGER %3$I;\n'
                      , p_partition_schema                      --<1: partition_schema>
                      , p_partition_name                        --<2: partition_name>
                      , partition_triggers.final_trigger_name   --<3: trigger_name>
                    )
             ELSE ''
           END
        )
        , E'\n'
          ORDER BY final_trigger_name
    )
      FROM partition_triggers;

$BODY$;
