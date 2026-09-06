/* Utility functions */

CREATE OR REPLACE FUNCTION pgpartix.table_exists (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$

/*
    * @param p_table_schema (text): The schema of the table.
    * @param p_table_name (text): The name of the table.

    * @return boolean: True if the table exists, false otherwise.
*/

    SELECT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_namespace AS n
         INNER JOIN pg_catalog.pg_class AS c
            ON n.oid = c.relnamespace
         WHERE n.nspname = p_table_schema
           AND c.relname = p_table_name
    );
$BODY$;

CREATE OR REPLACE FUNCTION pgpartix.tablespace_exists (
    p_tablespace text
)
RETURNS boolean
LANGUAGE SQL
AS $BODY$

/*
    * @param p_tablespace (text): The name of the tablespace.

    * @return boolean: True if the tablespace exists, false otherwise.
*/

    SELECT EXISTS (
        SELECT NULL
          FROM pg_catalog.pg_tablespace
         WHERE spcname = p_tablespace
    );
$BODY$;

CREATE OR REPLACE FUNCTION pgpartix.get_relation_tablespace (
    p_relation_schema text
  , p_relation_name text
)
RETURNS text
LANGUAGE SQL
AS $BODY$

/*
    * @param p_relation_schema (text): The schema of the relation.
    * @param p_relation_name (text): The name of the relation.

    * @return text: The name of the tablespace of the relation.
*/

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

CREATE OR REPLACE FUNCTION pgpartix.render_template (
    p_template text,
    p_values jsonb
)
RETURNS text
LANGUAGE plpgsql
STRICT
IMMUTABLE
AS $BODY$

/*
    * @param p_template (text): The template string containing placeholders to be replaced.
    * @param p_values (jsonb): A JSONB object containing key-value pairs for
        replacing placeholders in the template string.

    * @return text: The rendered string with placeholders replaced by corresponding values from the JSONB object.
*/

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

CREATE OR REPLACE FUNCTION pgpartix.is_table_partitioned (
    p_table_schema text
  , p_table_name text
)
RETURNS boolean
LANGUAGE SQL
STRICT
AS $BODY$

/*
    * @param p_table_schema (text): The schema of the table.
    * @param p_table_name (text): The name of the table.

    * @return boolean: True if the table is partitioned, false otherwise.
*/

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

CREATE OR REPLACE FUNCTION pgpartix.get_partitioning_details (
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

/*
    * @param p_table_schema (text): The schema of the table.
    * @param p_table_name (text): The name of the table.

    * @return number_of_keys: The number of partitioning keys.
    * @return strategy: The partitioning strategy (RANGE, LIST, or HASH).
    * @return keys: The names of the partitioning keys.
    * @return keys_data_types: The data types of the partitioning keys.
*/

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

CREATE OR REPLACE FUNCTION pgpartix.get_storage_parameters (
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

/*
    * @param p_relation_schema (text): The schema of the relation.
    * @param p_relation_name (text): The name of the relation.

    * @return source_order: The order of the source (1 for relation, 2 for toast).
    * @return source_kind: The kind of the source (relation or toast).
    * @return parameter_position: The position of the parameter in the source.
    * @return parameter_key: The key of the storage parameter.
    * @return parameter_value: The value of the storage parameter.
*/

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

CREATE OR REPLACE FUNCTION pgpartix.render_storage_parameters (
    p_relation_schema text
  , p_relation_name text
  , p_user_config jsonb DEFAULT NULL
  , p_format text DEFAULT '%1$s = %2$s'
)
RETURNS text
LANGUAGE SQL
AS $BODY$

/*
    * @param p_relation_schema (text): The schema of the relation.
    * @param p_relation_name (text): The name of the relation.
    * @param p_user_config (jsonb): A JSONB object containing user-defined storage parameters to override the default ones.
    * @param p_format (text): A format string for rendering the storage parameters.
        The default format is '%1$s = %2$s', where %1$s is the parameter key and %2$s is the parameter value.

    * @return text: A string representation of the storage parameters in the specified format.
*/

    WITH base_parameters AS (
        SELECT source_order
             , parameter_position
             , parameter_key
             , COALESCE(
                   p_user_config ->> parameter_key
                 , parameter_value
               ) AS parameter_value
          FROM pgpartix.get_storage_parameters(
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
