CREATE OR REPLACE FUNCTION pgpartium.expire_partitions (
    p_table_schema text
  , p_table_name text
  , p_retention interval
  , p_timezone text = 'UTC'
)
RETURNS SETOF text
LANGUAGE plpgsql
SET search_path TO ''
AS $BODY$
DECLARE
    v_parent_exists            boolean;
    v_is_parent_partitioned    boolean;

BEGIN

    PERFORM set_config('timezone', p_timezone, true);

    v_parent_exists := pgpartium.table_exists(p_table_schema, p_table_name);
    v_is_parent_partitioned := pgpartium.is_table_partitioned(p_table_schema, p_table_name);

    IF NOT v_parent_exists THEN
        RAISE 'table "%"."%" does not exist', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    IF NOT v_is_parent_partitioned THEN
        RAISE 'table "%"."%" is not partitioned', p_table_schema, p_table_name
        USING ERRCODE = 'undefined_table';
    END IF;

    RETURN QUERY SELECT string_agg(
        'DROP TABLE '
        || partition_schema
        || '.'
        || partition_name,
        E';\n\n'
        ORDER BY partition_name
    ) || E';'
      FROM pgpartium.get_expired_partitions(p_table_schema, p_table_name, p_retention)
    HAVING COUNT(*) > 0;

END;

$BODY$;
