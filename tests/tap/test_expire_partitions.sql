BEGIN;

-- Deallocate all previous prepared statements.
DEALLOCATE ALL;

SET search_path TO mock, pg_catalog, public;

-- Plan the tests.
SELECT plan(16);

-- Run the tests.
-- Group: Exceptions

-- Group: Outputs
