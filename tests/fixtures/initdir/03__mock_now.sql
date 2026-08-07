-- Partition lifecycle relies on the current timestamp to determine which partitions to create or manage.
-- To ensure that tests are deterministic and not affected by the actual current time, we are mocking the now()
-- function to return a fixed timestamptz value. This allows us to have consistent test results regardless
-- of when the tests are run.
-- To override the timestamp for specific tests, set the `mock.freeze_time` GUC to the desired timestamptz value
-- using the `ALTER SYSTEM` command.

CREATE SCHEMA IF NOT EXISTS mock;

CREATE OR REPLACE FUNCTION mock.now ()
RETURNS timestamptz
LANGUAGE SQL
STABLE
PARALLEL SAFE
AS $BODY$
    SELECT COALESCE(
               NULLIF(
                   pg_catalog.current_setting('mock.now')
                 , 'disabled'
               )::timestamptz
             , pg_catalog.now()
           );
$BODY$;
