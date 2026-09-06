CREATE OR REPLACE FUNCTION pgpartix.get_triggers (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    trigger_name text
  , is_trigger_enabled boolean
  , is_constraint_trigger boolean
  , trigger_function_schema text
  , trigger_function_name text
  , event_timing text
  , trigger_event text
  , ordinal integer
  , trigger_body text
)
LANGUAGE SQL
AS $BODY$

/*
    * @param p_table_schema (text): The schema of the table.
    * @param p_table_name (text): The name of the table.

    * @return trigger_name (text): The name of the trigger.
    * @return is_trigger_enabled (boolean): True if the trigger is enabled, false otherwise.
    * @return is_constraint_trigger (boolean): True if the trigger is a constraint trigger, false otherwise.
    * @return trigger_function_schema (text): The schema of the trigger function.
    * @return trigger_function_name (text): The name of the trigger function.
    * @return event_timing (text): The timing of the trigger event ('BEFORE', 'AFTER', or 'INSTEAD OF').
    * @return trigger_event (text): The event that fires the trigger ('INSERT', 'UPDATE', 'DELETE', or 'TRUNCATE').
    * @return ordinal (integer): The ordinal number of the trigger, when there are two or more triggers with the same event timing, event and body.
    * @return trigger_body (text): The body of the trigger function.
*/

    WITH triggers AS (
        SELECT tg.oid AS trigger_oid
             , tg.tgname AS trigger_name
             , CASE tg.tgenabled
                 WHEN 'D'
                   THEN FALSE
                 ELSE TRUE
               END AS is_trigger_enabled
             , CASE tg.tgconstraint
                 WHEN 0
                   THEN FALSE
                 ELSE TRUE
               END AS is_constraint_trigger
             , pn.nspname AS trigger_function_schema
             , p.proname AS trigger_function_name
             , CASE CAST(tgtype AS integer) & 66
                 WHEN 2
                   THEN 'BEFORE'
                 WHEN 64
                   THEN 'INSTEAD OF'
                 ELSE 'AFTER'
               END AS event_timing
             , replace(
                trim(
                      BOTH FROM (
                         CASE
                           WHEN (CAST(tgtype AS integer) & 4) = 0
                             THEN ''
                           ELSE ' INSERT'
                         END
                         ||
                         CASE
                           WHEN (CAST(tgtype AS integer) & 8) = 0
                             THEN ''
                           ELSE ' DELETE'
                         END
                         ||
                         CASE
                           WHEN (CAST(tgtype AS integer) & 16) = 0
                             THEN ''
                           ELSE ' UPDATE'
                         END
                         ||
                         CASE
                           WHEN (CAST(tgtype AS integer) & 32) = 0
                             THEN ''
                           ELSE ' TRUNCATE'
                         END
                      )
                    )
                , ' '
                , ' OR '
               ) AS trigger_event
             , substring(pg_catalog.pg_get_triggerdef(tg.oid, TRUE) FROM 'ON [\w.]+ (.*)') AS trigger_body
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS t
            ON n.oid = t.relnamespace
         INNER JOIN pg_catalog.pg_trigger AS tg
            ON t.oid = tg.tgrelid
           AND NOT tg.tgisinternal
         INNER JOIN pg_catalog.pg_proc AS p
            ON p.oid = tg.tgfoid
         INNER JOIN pg_catalog.pg_namespace AS pn
            ON pn.oid = p.pronamespace
         WHERE n.nspname = p_table_schema
           AND t.relname = p_table_name
    )
    SELECT trigger_name
         , is_trigger_enabled
         , is_constraint_trigger
         , trigger_function_schema
         , trigger_function_name
         , event_timing
         , trigger_event
         , row_number() OVER (
               PARTITION BY event_timing, trigger_event, trigger_body
               ORDER BY trigger_oid
           ) - 1 AS ordinal
         , trigger_body
      FROM triggers;
$BODY$;
