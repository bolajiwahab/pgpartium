/* Utility functions */
CREATE OR REPLACE FUNCTION pgpartium.table_exists (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$
    SELECT EXISTS (
        SELECT 1
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
    SELECT t.spcname AS tablespace_name
      FROM pg_catalog.pg_namespace AS n
     INNER JOIN pg_catalog.pg_class AS c
        ON n.oid = c.relnamespace
     INNER JOIN pg_catalog.pg_tablespace AS t
        ON c.reltablespace = t.oid
     WHERE n.nspname = p_relation_schema
       AND c.relname = p_relation_name;
$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.merge_configs (
    p_base_config jsonb
  , p_override jsonb
)
RETURNS jsonb
LANGUAGE SQL
IMMUTABLE
AS $BODY$

    SELECT COALESCE(p_base_config, '{}'::jsonb) || COALESCE(p_override, '{}'::jsonb);

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
        SELECT t.v_key, t.v_value FROM jsonb_each_text(p_values) AS t(v_key, v_value)
    LOOP
        v_result := replace(v_result, v_key, v_value);
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
RETURNS jsonb
LANGUAGE SQL
AS $BODY$

    WITH raw_storage_parameters AS (
        SELECT position
             , split_part(parameter, '=', 1) AS key
             , split_part(parameter, '=', 2) AS value
          FROM pg_catalog.pg_class
          JOIN pg_catalog.pg_namespace
            ON pg_class.relnamespace = pg_namespace.oid
         CROSS JOIN LATERAL unnest(reloptions) WITH ORDINALITY AS t(parameter, position)
         WHERE pg_namespace.nspname = p_relation_schema
           AND pg_class.relname = p_relation_name
    )
    SELECT jsonb_object_agg(key, value) AS parameters
      FROM raw_storage_parameters;

$BODY$;

CREATE OR REPLACE FUNCTION pgpartium.render_storage_parameters (
    p_config jsonb
)
RETURNS text
LANGUAGE SQL
STRICT
AS $BODY$

    SELECT CASE
             WHEN p_config = '{}'::jsonb
               THEN ''
             ELSE
               'WITH (' ||
               string_agg(
                   format('%I = %L', v_key, v_value),
                   ', '
               ) ||
               ')'
           END
      FROM jsonb_each_text(p_config) AS parameters(v_key, v_value)

$BODY$;
