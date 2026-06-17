CREATE OR REPLACE FUNCTION pgpartium.generate_trigger_constraints (
    p_parent_table_schema text
  , p_parent_table_name text
  , p_partition_schema text
  , p_partition_name text
  , p_template_table_schema text
  , p_template_table_name text
  , p_idempotency boolean
)
RETURNS text
LANGUAGE SQL
AS $BODY$

    WITH template_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(p_table_schema=>p_template_table_schema, p_table_name=>p_template_table_name)
    )
    , parent_triggers AS (
        SELECT trigger_name
             , is_trigger_enabled
             , is_constraint_trigger
             , event_timing
             , trigger_event
             , trigger_body
          FROM pgpartium.get_triggers(p_table_schema=>p_parent_table_schema, p_table_name=>p_parent_table_name)
    )
    , partition_triggers AS (
        SELECT replace(
                   template_triggers.trigger_name
                 , p_template_table_name
                 , p_partition_name
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
            ON template_triggers.event_timing = parent_triggers.event_timing
           AND template_triggers.trigger_event = parent_triggers.trigger_event
           AND template_triggers.trigger_body = parent_triggers.trigger_body
         WHERE parent_triggers.trigger_body IS NULL
    )
    SELECT string_agg(
        format(
           E'CREATE %1$s%2$s %3$I %4$s %5$s\n    ON %6$I.%7$I\n   %8$s;\n%9$s'
         , CASE p_idempotency                                --<1: idempotence>
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
