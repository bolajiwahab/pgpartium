/* Utility functions */

CREATE OR REPLACE FUNCTION pgpartium.table_exists (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$
    SELECT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS c
            ON n.oid = c.relnamespace
         WHERE n.nspname = p_table_schema
           AND c.relname = p_table_name
    );
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.tablespace_exists (
    p_tablespace text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$
    SELECT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_tablespace
    );
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.get_relation_tablespace (
    p_relation_schema text
  , p_relation_name text
)
RETURNS text
LANGUAGE SQL
AS $BODY$
    SELECT ts.spcname AS tablespace_name
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS c
        ON n.oid = c.relnamespace
     CROSS JOIN pg_catalog.pg_database AS d
     INNER JOIN pg_catalog.pg_tablespace AS ts
        ON ts.oid = COALESCE(
                        NULLIF(c.reltablespace, 0),
                        d.dattablespace
                    )
    WHERE d.datname = pg_catalog.current_database()
      AND n.nspname = p_relation_schema
      AND c.relname = p_relation_name;
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.render_template (
    p_template text,
    p_values jsonb
)
RETURNS text
LANGUAGE plpgsql
STRICT
IMMUTABLE
AS $BODY$
DECLARE
    v_result text := p_template;
    v_key text;
    v_value text;
BEGIN
    FOR v_key, v_value IN
        SELECT t.v_key
             , t.v_value
          FROM jsonb_each_text(p_values) AS t(v_key, v_value)
    LOOP
        v_result := replace(
                        v_result
                      , v_key
                      , v_value
                    );
    END LOOP;

    RETURN v_result;
END;
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.is_table_partitioned (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
STRICT
AS $BODY$
    SELECT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS c
            ON n.oid = c.relnamespace
         WHERE n.nspname = p_table_schema
           AND c.relname = p_table_name
           AND c.relkind = 'p'
    );
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.get_partitioning_details (
    p_table_schema text
  , p_table_name text
)
RETURNS TABLE (
    number_of_keys smallint
  , strategy text
  , keys text
  , keys_data_types text
)
LANGUAGE SQL
STRICT
AS $BODY$
    SELECT p.partnatts AS number_of_keys
         , CASE p.partstrat
             WHEN 'r'
               THEN 'RANGE'
             WHEN 'l'
               THEN 'LIST'
             WHEN 'h'
               THEN 'HASH'
           END AS strategy
         , string_agg(a.attname, ', ') AS keys
         , string_agg(t.typname, ', ') AS keys_data_types
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS c
        ON n.oid = c.relnamespace
     INNER JOIN pg_catalog.pg_partitioned_table AS p
        ON c.oid = p.partrelid
     INNER JOIN pg_catalog.pg_attribute AS a
        ON p.partrelid = a.attrelid
       AND a.attnum = ANY(CAST(p.partattrs AS integer[]))
     INNER JOIN pg_catalog.pg_type AS t
        ON a.atttypid = t.oid
     WHERE n.nspname = p_table_schema
       AND c.relname = p_table_name
     GROUP BY n.nspname
            , c.relname
            , p.partrelid
            , p.partnatts
            , p.partstrat;
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.get_storage_parameters (
    p_relation_schema text
  , p_relation_name text
)
RETURNS TABLE (
    source_order integer
  , source_kind text
  , parameter_position bigint
  , parameter_key text
  , parameter_value text
)
LANGUAGE SQL
STRICT
AS $BODY$

    WITH relation_options AS (
        SELECT 1 AS source_order
             , 'relation' AS source_kind
             , parameter_position
             , split_part(o.parameter, '=', 1) AS parameter_key
             , split_part(o.parameter, '=', 2) AS parameter_value
          FROM pg_catalog.pg_namespace AS n
          JOIN pg_catalog.pg_class AS c
            ON n.oid = c.relnamespace
         CROSS JOIN LATERAL unnest(reloptions)
          WITH ORDINALITY AS o(parameter, parameter_position)
         WHERE n.nspname = p_relation_schema
           AND c.relname = p_relation_name
    )
    , toast_options AS (
        SELECT 2 AS source_order
             , 'toast' AS source_kind
             , parameter_position
             , format('%1$I.%2$I', 'toast', split_part(o.parameter, '=', 1)) AS parameter_key
             , split_part(o.parameter, '=', 2) AS parameter_value
          FROM pg_catalog.pg_namespace AS n
          JOIN pg_catalog.pg_class AS c
            ON n.oid = c.relnamespace
          JOIN pg_catalog.pg_class AS t
            ON t.oid = c.reltoastrelid
         CROSS JOIN LATERAL unnest(t.reloptions)
          WITH ORDINALITY AS o(parameter, parameter_position)
         WHERE n.nspname = p_relation_schema
           AND c.relname = p_relation_name
    )
    SELECT source_order
         , source_kind
         , parameter_position
         , parameter_key
         , parameter_value
      FROM relation_options
     UNION ALL
    SELECT source_order
         , source_kind
         , parameter_position
         , parameter_key
         , parameter_value
      FROM toast_options;

$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.render_storage_parameters (
    p_relation_schema text
  , p_relation_name text
  , p_user_config jsonb DEFAULT NULL
  , p_format text DEFAULT '%1$s = %2$s'
)
RETURNS text
LANGUAGE SQL
AS $BODY$

    WITH base_parameters AS (
        SELECT source_order
             , parameter_position
             , parameter_key
             , COALESCE(
                   p_user_config ->> parameter_key
                 , parameter_value
               ) AS parameter_value
          FROM pgpartium.get_storage_parameters(
                   p_relation_schema,
                   p_relation_name
               )
    )
    , merged_parameters AS (
        SELECT source_order
             , parameter_position
             , parameter_key
             , parameter_value
          FROM base_parameters
         UNION ALL
        SELECT 3 AS source_order
             , row_number() OVER (ORDER BY o.key) AS parameter_position
             , o.key AS parameter_key
             , o.value AS parameter_value
          FROM jsonb_each_text(
                   COALESCE(
                       p_user_config
                     , '{}'::jsonb
                   )
               ) AS o(key, value)
         WHERE NOT EXISTS (
                   SELECT
                     FROM base_parameters AS b
                    WHERE b.parameter_key = o.key
               )
    )
    SELECT 'WITH ('
           ||
           string_agg(
               format(
                   p_format
                 , parameter_key
                 , parameter_value
               )
               , ', '
               ORDER BY source_order
                      , parameter_position
           )
           ||
           ')'
      FROM merged_parameters;

$BODY$;
