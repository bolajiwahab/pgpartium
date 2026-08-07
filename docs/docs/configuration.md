# Configuration reference

pgpartium reads one YAML file or every `.yaml` and `.yml` file in a directory. The same configuration drives both sides of the lifecycle:

- `pgp-make-partitions` generates DDL for partitions that should exist.
- `pgp-expire-partitions` generates DDL for partitions whose upper bounds have passed the retention window.

Neither command applies the generated lifecycle migration to the source database. They inspect the PostgreSQL database and write reviewable SQL files for the repository's normal migration process.

## Minimal configuration

```yaml
---
lifecycle:
  directory: migrations/partitions
  partition:
    naming:
      template: "{parent_table_schema}__{parent_table_name}__YYYY_MM"
    interval: 1 month
    retention:
      interval: 12 months
  tables:
    - schema: public
      name: transactions
```

`lifecycle.tables` is required. Partition creation is skipped for a table when `partition.interval` is omitted; when `partition.interval` is present, `partition.naming.template` must also be present, globally or on that table. Expiration produces no SQL when `retention.interval` is omitted or `null`.

The output directory must exist before the command runs. The partitioned tables, configured schemas, tablespaces, and optional template tables must also exist in the database being inspected.

## Inheritance and overrides

Options under `lifecycle` apply to all tables. A table can override `description`, `output_file_template`, or individual `partition` options.

```yaml
lifecycle:
  partition:
    interval: 1 month
    retention:
      interval: 12 months
      detach_first: true
      detach_concurrently: true
  tables:
    - schema: public
      name: transactions
    - schema: public
      name: audit_events
      partition:
        interval: 1 week
        retention:
          interval: 26 weeks
          detach_only: true
          detach_first: false
          detach_concurrently: false
```

Overrides are resolved per field, including explicit `false` values. In the example, `audit_events` inherits unrelated defaults but disables the global detach settings.

## Top-level lifecycle options

| Option | Type | Default | Scope | Purpose |
| --- | --- | --- | --- | --- |
| `lifecycle.directory` | string | `.` | Global | Existing directory where migration files are published. |
| `lifecycle.timezone` | IANA timezone | `Etc/UTC` | Global | Time context used for partition bounds and expiration calculations. |
| `lifecycle.description.make` | string | `Make partitions for {parent_table_schema}.{parent_table_name}` | Global or table | Description used when naming creation migrations and composing the PR body. |
| `lifecycle.description.expire` | string | `Expire partitions for {parent_table_schema}.{parent_table_name}` | Global or table | Description used when naming expiration migrations and composing the PR body. |
| `lifecycle.output_file_template` | string | `pgpartium_output.sql` | Global or table | Template for the generated migration filename. |
| `lifecycle.idempotent` | boolean | `false` | Global or table | Add supported `IF NOT EXISTS`, `CREATE OR REPLACE` to generated DDL. |
| `lifecycle.partition` | object | none | Global or table | Creation, replication, storage, and expiration behavior. |
| `lifecycle.tables` | array | required | Global | Parent tables whose lifecycle should be evaluated. |

### Table entries

| Option | Required | Description |
| --- | --- | --- |
| `schema` | Yes | Schema of the partitioned table. |
| `name` | Yes | Name of the partitioned table. |
| `description` | No | Per-table `make` and/or `expire` descriptions. |
| `output_file_template` | No | Per-table migration filename template. |
| `idempotent` | No | Per-table override for `lifecycle.idempotent`. |
| `partition` | No | Per-table overrides for partition options. |
| `template` | No | Object or symbolic source used to replicate constraints, indexes, and triggers. |

## Output filenames

`output_file_template` supports the following placeholders:

| Placeholder | Meaning |
| --- | --- |
| `{description}` | Resolved lifecycle description, lowercased with whitespace replaced by underscores. |
| `{integer}` | Next unpadded integer based on matching files already in the output (migration) directory. |
| `{integer:N}` | Next integer padded to `N` digits, for example `{integer:3}` becomes `001`. |
| `{timestamp}` | Execution timestamp formatted as `YYYYMMDDHHMMSS`. |
| `{epoch}` | Unix epoch at execution time. |
| `{date}` | UTC date formatted as `YYYYMMDD`. |
| `{year}` | Four-digit UTC year. |
| `{month}` | Two-digit UTC month. |
| `{day}` | Two-digit UTC day. |
| `{hour}` | Two-digit UTC hour. |
| `{direction}` | Migration direction; currently always `up`. |

The descriptions themselves support `{parent_table_schema}` and `{parent_table_name}`. These are resolved before the description is inserted into the filename.

```yaml
lifecycle:
  description:
    make: "Make partitions for {parent_table_schema}_{parent_table_name}"
  output_file_template: "V{integer:4}__{description}.{direction}.sql"
```

Multiple successful tables may target one filename, depending on the provided `output_file_template`. pgpartium formats each table's SQL independently and appends the successful results in configuration order. A failed table does not discard successful output and does not contribute partial SQL. The command still exits nonzero and reports every failed table so automation remains visibly unhealthy.

## Partition creation options

These options are consumed primarily by `pgp-make-partitions`.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `partition.naming.template` | string | required when `partition.interval` is set | Name template for time-based partitions. |
| `partition.schema` | string | parent schema | Schema in which new partitions are created. |
| `partition.tablespace` | string | `null` | Tablespace for new partitions. |
| `partition.interval` | positive PostgreSQL interval | `null` | Interval between lower and upper bounds. Generation is skipped for a table when this is omitted, globally and on the table. |
| `partition.start_timestamp` | RFC 3339 timestamp, `NOW`, or `LATEST_PARTITION` | `null` | Initial point used to generate the series of desired partitions. |
| `partition.past` | nonnegative integer | `0` | Number of intervals before the resolved start point to include. |
| `partition.future` | nonnegative integer | `0` | Number of intervals beyond the current time to include. |
| `partition.default.naming.template` | string | `null` | Creates a default partition with this name when one does not exist. |
| `partition.retention.interval` | interval | `null` | Filters creation candidates whose upper bounds fall outside the retention window. Also drives expiration. |
| `partition.skip_overlapping` | boolean | `false` | Skip partitions whose bounds will overlap existing partitions instead of generating conflicting DDL. |

- Setting `partition.interval` without a resolvable `partition.naming.template` fails with `partition name template is required when partition interval is specified`.
- A zero interval fails with `interval cannot be zero`.
- `partition.past` and `partition.future` must be nonnegative.

### Partition naming

Partition names support `{parent_table_schema}`, `{parent_table_name}`, and PostgreSQL `to_char` date/time patterns. Common patterns include:

| Cadence | Example template | Example name |
| --- | --- | --- |
| Year | `{parent_table_schema}__{parent_table_name}__YYYY` | `public__events__2025` |
| Month | `{parent_table_schema}__{parent_table_name}__YYYY_MM` | `public__events__2025_04` |
| ISO week | `{parent_table_schema}__{parent_table_name}__IYYY_IW` | `public__events__2025_14` |
| Day | `{parent_table_schema}__{parent_table_name}__YYYY_MM_DD` | `public__events__2025_04_01` |
| Hour | `{parent_table_schema}__{parent_table_name}__YYYY_MM_DD_HH24` | `public__events__2025_04_01_13` |
| Minute | `{parent_table_schema}__{parent_table_name}__YYYY_MM_DD_HH24_MI` | `public__events__2025_04_01_13_30` |
| Second | `{parent_table_schema}__{parent_table_name}__YYYY_MM_DD_HH24_MI_SS` | `public__events__2025_04_01_13_30_00` |

Use a naming pattern whose precision distinguishes every configured interval. A monthly interval with only `YYYY`, for example, would produce duplicate names.

### Start timestamps and existing partitions

- `NOW` starts from the current timestamp in `lifecycle.timezone`.
- An RFC 3339 value provides a stable explicit start point.
- `LATEST_PARTITION` uses the upper bound of the most recent attached partition and fails clearly when no such partition exists.

The SQL generator also considers the current latest upper bound, avoids exact existing bounds, and generates only missing ranges.

### Supported parent tables

Current generation and expiration support:

- PostgreSQL 14 or newer;
- single-column `RANGE` partitioning;
- partition keys of `date`, `timestamp`, `timestamptz`, `integer`, `bigint`, or UUIDv7-compatible `uuid` values.

List/hash partitioning, multicolumn partition keys, and other key data types are rejected with table-specific errors.

## Template tables and object replication

`template` selects a relation whose objects should be reproduced on newly generated partitions:

```yaml
tables:
  - schema: public
    name: transactions
    template:
      schema: public
      name: transactions_template
```

It may also be one of:

- `CURRENT_PARTITION`: the partition containing the current time;
- `LATEST_PARTITION`: the attached partition with the greatest upper bound;
- `DEFAULT_PARTITION`: the parent's default partition.

pgpartium replicates template constraints, indexes, and user triggers that are not already represented by the parent table. Trigger enabled/disabled state is preserved. `NOT NULL` attributes are part of the table's logical data model and are inherited through PostgreSQL partitioning rather than replicated as separate template constraints.

The selected template must exist. Symbolic sources fail with a useful message when no matching partition exists.

## Storage parameters

```yaml
partition:
  storage:
    mode: merge
    parameters:
      fillfactor: 80
      autovacuum_enabled: true
      toast.vacuum_index_cleanup: false
```

| Mode | Behavior |
| --- | --- |
| `override` | Use only configured `parameters`. This is the default. |
| `inherit` | Copy storage parameters from the selected template table and ignore configured parameters. |
| `merge` | Copy template parameters, then replace matching keys with configured values. |

`inherit` and `merge` are most useful with `template`. Storage parameter names and values are rendered into PostgreSQL `WITH (...)` clauses; PostgreSQL remains the authority on whether a parameter is valid for the generated relation.

## Index configuration

```yaml
partition:
  index:
    naming:
      template: "{partition_name}_{index_keys}_{index_type}_idx{ordinal}"
    tablespace: fast_indexes
```

`partition.index.tablespace` moves replicated indexes to an existing tablespace. When `partition.index.naming.template` is `null` or omitted, PostgreSQL chooses names for replicated indexes. A custom template supports:

- `{parent_table_schema}` and `{parent_table_name}`;
- `{partition_schema}` and `{partition_name}`;
- `{index_keys}`;
- `{index_type}`, such as `btree`;
- `{ordinal}`, empty for the first equivalent key set and numbered for additional ones.

Unique, partial, expression, and storage-parameter-bearing indexes are preserved from the template definition.

## Constraint naming

```yaml
partition:
  constraint:
    naming:
      template: "{partition_name}_{constraint_keys}_{constraint_suffix}{ordinal}"
      primary_key:
        template: "{partition_name}_pkey"
      unique_key:
        template: "{partition_name}_{constraint_keys}_key{ordinal}"
      foreign_key:
        template: "{partition_name}_{constraint_keys}_fkey{ordinal}"
      check:
        template: "{partition_name}_{constraint_keys}_check{ordinal}"
      exclusion:
        template: "{partition_name}_{constraint_keys}_excl{ordinal}"
```

The generic `naming.template` is the fallback for a type without its own template. The primary-key default is `{partition_name}_pkey`; other types fall back to the generic template.

Available placeholders are:

- `{parent_table_schema}` and `{parent_table_name}`;
- `{partition_schema}` and `{partition_name}`;
- `{constraint_keys}`;
- `{constraint_suffix}`: `pkey`, `key`, `fkey`, `check`, or `excl`;
- `{ordinal}`, empty for the first matching constraint and numbered thereafter.

The supported type keys are `primary_key`, `unique_key`, `foreign_key`, `check`, and `exclusion`.

## Trigger naming

```yaml
partition:
  trigger:
    naming:
      template: "{partition_name}_{event_timing}_{trigger_event}_{trigger_function_name}{ordinal}"
```

When `partition.trigger.naming.template` is `null`, it defaults to `{partition_name}_{event_timing}_{trigger_event}_{trigger_function_name}{ordinal}`. A custom template supports:

- `{parent_table_schema}` and `{parent_table_name}`;
- `{partition_schema}` and `{partition_name}`;
- `{event_timing}`, such as `BEFORE`, `AFTER`, or `INSTEAD OF`;
- `{trigger_event}`, such as `INSERT` or `UPDATE OR DELETE`;
- `{trigger_function_schema}` and `{trigger_function_name}`;
- `{ordinal}`, empty for the first trigger sharing the same timing, event, and body, and numbered for additional ones.

Trigger enabled/disabled state is preserved regardless of naming.

## Expiration options

These options are consumed by `pgp-expire-partitions`.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `partition.retention.interval` | interval | `null` | A partition expires when its upper bound is at least this old. |
| `partition.retention.detach_only` | boolean | `false` | Generate `ALTER TABLE ... DETACH PARTITION` without dropping the partition. |
| `partition.retention.detach_first` | boolean | `false` | Detach each expired partition and then drop it. |
| `partition.retention.detach_concurrently` | boolean | `false` | Add `CONCURRENTLY` to generated detach statements. |
| `lifecycle.idempotent` / `idempotent` | boolean | `false` | Add supported existence guards to generated DDL. |

Mode precedence is:

1. `detach_only: true` generates detach statements only.
2. Otherwise, `detach_first: true` generates detach followed by drop.
3. Otherwise, pgpartium generates direct `DROP TABLE` statements.

`detach_concurrently` has an effect only when a detach statement is generated.

PostgreSQL does not support `DETACH PARTITION IF EXISTS`. With `idempotent: true`, pgpartium can guard the parent table and drop statements, but detach operations remain only partially idempotent if a partition has already been detached outside the generated migration.

## Connection environment

Both lifecycle commands read:

| Variable | Purpose |
| --- | --- |
| `PGP_USER` | PostgreSQL user. |
| `PGP_PASSWORD` | PostgreSQL password. |
| `PGP_HOST` | PostgreSQL host. |
| `PGP_PORT` | PostgreSQL port. |
| `PGP_DATABASE` | Database containing the partitioned tables. |

The commands default these values to `postgres`, `postgres`, `localhost`, `5432`, and `postgres` respectively for the disposable local cluster. Local-cluster users do not need to define them. External databases must override every value explicitly; see [Database environment](cli-reference.md#database-environment).

Pass a directory to `-c` to process multiple configuration files in sorted filename order.

## Failure and publication behavior

Each table is generated and formatted independently in a staging directory. At the end of a run:

- SQL from successful tables is published, including successful tables sharing one output file;
- failed and partially formatted table output is discarded;
- existing unrelated migrations remain untouched;
- every failed table and its PostgreSQL error are reported;
- the command exits with status `1` when any table failed.

This gives local and automated runs useful partial progress without disguising failures. Successful migrations can be reviewed or published while the nonzero exit status still identifies tables requiring intervention.

## Complete example

See [`config.sample.yaml`](../../config.sample.yaml) for a current, annotated configuration containing global defaults, table overrides, naming templates, storage behavior, template replication, and expiration modes. The schema is available at [schema](https://bolajiwahab.github.io/pgpartium/schema.html).
