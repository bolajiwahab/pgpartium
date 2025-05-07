-- migrate:up

CREATE SCHEMA mock;

-- We are mocking now() to return a fixed timestamptz value
-- as the core function pgpartium.make_partitions uses now()
-- to calculate the partitioning range.
CREATE OR REPLACE FUNCTION mock.now ()
RETURNS timestamptz
LANGUAGE SQL
IMMUTABLE
PARALLEL SAFE
AS $BODY$
    SELECT CAST('2025-03-01 00:00:00' AS timestamptz);
$BODY$;
