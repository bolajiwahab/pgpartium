CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT format($SQL$
    CREATE TABLESPACE %1$I
      LOCATION '/var/lib/postgresql/tablespaces/%1$I';
$SQL$, 'pgpartium')
 WHERE NOT EXISTS (
    SELECT NULL
      FROM pg_catalog.pg_tablespace
     WHERE spcname = 'pgpartium')\gexec

CREATE SCHEMA IF NOT EXISTS mock;

-- We are mocking now() to return a fixed timestamptz value
-- for deterministic tests
CREATE OR REPLACE FUNCTION mock.now ()
RETURNS timestamptz
LANGUAGE SQL
STABLE
PARALLEL SAFE
AS $BODY$
    SELECT CAST('2025-03-01 00:00:00' AS timestamptz);
$BODY$;

ALTER SYSTEM SET search_path = mock, pg_catalog, public;
