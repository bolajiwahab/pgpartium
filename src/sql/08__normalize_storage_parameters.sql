-- select * from pgpartium.render_template('{parent_table_name}_{ordinal}', jsonb_build_object('{parent_table_name}', 'notifications_2026_01', '{ordinal}', 5));

CREATE OR REPLACE FUNCTION pgpartium.render_template (
    p_template text,
    p_values jsonb
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_result text := p_template;
    v_key text;
    v_value text;
BEGIN
    FOR v_key, v_value IN
        SELECT * FROM jsonb_each_text(p_values)
    LOOP
        v_result := replace(v_result, v_key, v_value);
    END LOOP;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION pgpartium.normalize_storage_parameters (
    p_relation_schema text
  , p_relation_name text
  , p_override jsonb DEFAULT '{}'
)
RETURNS TABLE (
    normalized_current_storage_parameters text
  , normalized_formatted_overridden_storage_parameters text
)
LANGUAGE SQL
AS $BODY$

    /*
    * @param p_relation_schema: The schema of the relation.
    * @param p_relation_name: The name of the relation.
    * @param p_override: JSON object to override the current storage parameters.
    *
    * @return normalized_current_storage_parameters
    *     Canonical storage parameter clause matching the formatting
    *     produced by pg_catalog.pg_get_indexdef().
    *
    * @return normalized_formatted_overridden_storage_parameters
    *     Human-friendly formatted storage parameter clause.
    *
    * Returns NULL for both outputs when no storage parameters exist
    * after merging. NULL represents the absence of a WITH (...)
    * clause and allows callers to compose SQL fragments without
    * introducing unnecessary whitespace or blank lines.
    */

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
    , storage_parameters_in_json AS (
        SELECT jsonb_object_agg(key, value) AS parameters
          FROM raw_storage_parameters
    )
    , merged_storage_parameters AS (
        SELECT COALESCE(storage_parameters_in_json.parameters, '{}'::jsonb)
               ||
               p_override AS parameters
          FROM storage_parameters_in_json
    )
    , normalized_current_storage_parameters AS (
        SELECT
            'WITH (' ||
            string_agg(
                format('%I=%L', key, value),
                ', ' ORDER BY position
            ) ||
            ')' AS parameters
        FROM raw_storage_parameters
    )
    , normalized_formatted_overridden_storage_parameters AS (
        SELECT
            'WITH (' ||
            string_agg(
                format('%I = %L', key, value),
                ', '
            ) ||
            ')' AS parameters
        FROM merged_storage_parameters
       CROSS JOIN LATERAL jsonb_each_text(merged_storage_parameters.parameters) AS parameters(key, value)
    )
    SELECT (SELECT parameters FROM normalized_current_storage_parameters)
         , (SELECT parameters FROM normalized_formatted_overridden_storage_parameters);

$BODY$;
