# TODO

Why I would not make inheritance the default:

Because tablespace is more environment / lifecycle / operational policy than schema definition.

** Important **
-- we need to test triggers with args
We need more name template rather than blindly replacing the template table name/schema with the partition name/schema
The issue is that there are cases where these replacers won't exist in the source/template indexes/triggers/constraints
leading to already existing indexes/triggers/constraints and thus statement errors.

- Index_name_template -> {partition_schema}__{index_columns}_{index_filter}_idx
- Table_name_template
- Partition_name_template
- Constraint_name_template
- Trigger_name_template

1. Support Index options such as AUTOSUMMARIZE =           DEDUPLICATE_ITEMS =       FILLFACTOR =              PAGES_PER_RANGE =
BUFFERING =               FASTUPDATE =              GIN_PENDING_LIST_LIMIT =

2. Need to support more storage options with regards to toast table
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

## Tests

<!-- 2. Template table tablespace with override -->
<!-- 3. Template index tablespace with override -->
<!-- 4. Template table storage parameters with override -->
<!-- 5. Template index storage parameters with override -->
<!-- 6. Test index_template_naming -->
7. Test constraint_template_naming , test exclusion, foreign key and check constraints
8. Test trigger_template_naming
9. Test for expression indexes


Your current behavior:

CHECK (status IS NOT NULL)
→ status

CHECK (status = ANY (...))
→ status

CHECK (lower(status) = status)
→ status

CHECK (lower(status) = status AND true)
→ status

is effectively saying:

"Which columns does this constraint depend on?"

rather than:

"What is the exact expression?"

That's usually the more useful metadata.

for index name conflicts, postgres uses index_keys, same thing for expression indexes
but for constraints, postgres uses constraint type and constraint keys to resolve conflicts
since constraint type is part of the default naming

✔ Corrected version of your first statement

PostgreSQL derives index base names from index keys (columns or expressions), and uses suffixing for conflicts.

✔ Corrected version of your second statement

PostgreSQL derives constraint base names from constraint type and associated columns/expressions, and uses suffixing for conflicts when needed.

c = check constraint, f = foreign key constraint, n = not-null constraint, p = primary key constraint, u = unique constraint, t = constraint trigger, x = exclusion constraint

This gives contributors a single primitive to use.

pg_prove --username=postgres --dbname=postgres --verbose --failures tests/tap/**/*.sql && \

bash shellspec tests/spec --no-warning-as-failure

we need constraint trigger and foreign key

###############################################
tests/
├── config/
│   ├── inherits_global
│   ├── overrides_global
│   └── required_fields
│
└── make_partitions/
    ├── create_default
    ├── future
    ├── past
    ├── retention
    ├── partition_schema
    ├── template_table
    ├── tablespace
    ├── storage_parameters
    ├── skip_overlapping
    ├── idempotent_ddl
    └── timezone

partition:
  naming:
    template: "..."

  default:
    naming:
      template: "..."

index:
  naming:
    template: "{table_schema}__{table_name}__{column}_{type}"
  storage_parameters:
    fillfactor: 90

constraint:
  naming:
    primary_key:
      template: "..."

    foreign_key:
      template: "..."

    unique:
      template: "..."

    check:
      template: "..."

which says:

"Default partitions inherit partition behavior; only their name differs."

That's a very clean mental model.

trigger_name_template: "{table_schema}__{table_name}__{trigger_timing}_{trigger_events}__{function_name}"
trigger_name_template: "{table_schema}__{table_name}__{timing}_{events}__{function_name}"


make fields required in the schema

for i in $(seq 1 100); do
    echo 'INFO: Waiting for database to be ready... (attempt $i/50)' && \
    bats --pretty --timing --show-output-of-passing-tests tests/conftest.sh
done

partition making is
incremental, safe, idempotent expansion

support serial partitions
p_start_partition
p_start_timestamp

hourly → start of current hour
daily → start of current day
monthly → start of current month
yearly → start of current year
