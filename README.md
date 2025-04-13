-- weekly -> dow in the year: calendar week
-- monthly -> start of the month: 01 of the month
-- yearly -> start of the year that is January 01
-- hourly -> current hour: 01:00:00

-- we do not support access method on partitions since that is inherited from the parent
-- see docs: When creating a partition, the table access method is the access method of its partitioned table, if set.
https://www.postgresql.org/docs/current/sql-createtable.html#:~:text=When%20creating%20a%20partition%2C%20the%20table%20access%20method%20is%20the%20access%20method%20of%20its%20partitioned%20table%2C%20if%20set.


select regexp_replace('CREATE INDEX tbl_con_ledger_id_idx2 ON partitions.enrichment__2025_02 USING btree (ledger_id)', '(WHERE .*)$', E'TABLESPACE ' || 'tablespace_name' || E' \\1', 'g')


select substring('CREATE INDEX tbl_con_ledger_id_idx2 ON partitions.enrichment__2025_02 USING btree (ledger_id) WHERE expires_at > 1' FROM '(WHERE .*)$') AS index_definition

needs to adjust queries to start from pg_namespace

we need to prevent creating file on failure

-- Raise note about usage of to_char internally, any character that should not be transformed needs to be escaped with double quotes
internally we use to_char for formatting date/time in the generation of the partition names.

-- outstanding
1. adjust config.yml as sample and update
2. update bash scripts with the new options
3. use named parameters instead of positional parameters in the bash scripts
4. tests for the bash scripts? call the program with the fixtures config and compare the outputs
5. update readme
6. enable yamllint
7.
