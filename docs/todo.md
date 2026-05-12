# TODO

** Important **
We need more name template rather than blindly replacing the template table name/schema with the partition name/schema
The issue is thst there are cases where these replacers won't exist in the source/template indexes/triggers/constraints
leading to already existing indexes/triggers/constraints and thus statement errors.

- Index_name_template -> {partition_schema}__{index_columns}_{index_filter}_idx
- Table_name_template
- Partition_name_template
- Constraint_name_template
- Trigger_name_template

1. Index options such as AUTOSUMMARIZE =           DEDUPLICATE_ITEMS =       FILLFACTOR =              PAGES_PER_RANGE =
BUFFERING =               FASTUPDATE =              GIN_PENDING_LIST_LIMIT =

2. Need to support more storage options with regards to toast
toast.autovacuum_enabled                     toast.autovacuum_multixact_freeze_table_age  toast.autovacuum_vacuum_threshold
toast.autovacuum_freeze_max_age              toast.autovacuum_vacuum_cost_delay           toast.log_autovacuum_min_duration
toast.autovacuum_freeze_min_age              toast.autovacuum_vacuum_cost_limit           toast.vacuum_index_cleanup
toast.autovacuum_freeze_table_age            toast.autovacuum_vacuum_insert_scale_factor  toast.vacuum_truncate
toast.autovacuum_multixact_freeze_max_age    toast.autovacuum_vacuum_insert_threshold

3. In get storage parameters
-- Get storage parameters.
-- We can probably support getting the storage parameters from the template table as well,
-- we then do dict comparison between the template table and the config and if an option is provided by both the with config takes precedence
-- otherwise we fall back to the provided ones from the config.
