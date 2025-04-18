CREATE OR REPLACE FUNCTION pgpartium.get_triggers (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    trigger_name text
  , is_constraint_trigger boolean
  , event_timing text
  , trigger_event text
  , trigger_body text
)
LANGUAGE SQL
AS $BODY$
    SELECT tg.tgname AS trigger_name
         , CASE tg.tgconstraint
             WHEN 0
               THEN FALSE
             ELSE TRUE
           END AS is_constraint_trigger
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
         , substring(pg_get_triggerdef(tg.oid, TRUE) FROM 'ON [\w.]+ (.*)') AS trigger_body
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS t
        ON n.oid = t.relnamespace
     INNER JOIN pg_catalog.pg_trigger AS tg
        ON t.oid = tg.tgrelid
       AND NOT tg.tgisinternal
     WHERE n.nspname = p_table_schema
       AND t.relname = p_table_name;
$BODY$;
