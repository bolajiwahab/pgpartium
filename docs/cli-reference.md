# CLI reference

The pgpartium image contains commands for preparing PostgreSQL and generating lifecycle migrations. It also includes an optional GitHub pull-request helper.

## Database environment

`pgp-make-partitions`, `pgp-expire-partitions`, and `pgp-setup-infrastructure` read these connection variables:

| Variable | Default | Description |
| --- | --- | --- |
| `PGP_USER` | `postgres` | PostgreSQL user. |
| `PGP_PASSWORD` | `postgres` | PostgreSQL password. |
| `PGP_HOST` | `localhost` | PostgreSQL host. |
| `PGP_PORT` | `5432` | PostgreSQL port. |
| `PGP_DATABASE` | `postgres` | Database containing the partitioned schema. |

These defaults target the disposable local cluster created by `pgp-start`, so local-cluster users do not need to provide credentials or endpoints. They are not recommended production credentials. When connecting to an external catalog, override all five explicitly.

External catalog example:

```bash
export PGP_USER=partition_catalog_reader
export PGP_PASSWORD='...'
export PGP_HOST=postgres.example.internal
export PGP_PORT=5432
export PGP_DATABASE=application_catalog
```

## `pgp-start`

Installs a PostgreSQL major version and its client. Unless `NO_CLUSTER=1` is set, it creates and starts a local cluster and optionally applies an initialization directory.

```text
OPTIONS:
  -v  PostgreSQL major version (default: 14, at least 14)
  -i  Initialization directory (optional; supports .sh, .sql, .sql.gz)
  -h  Show help
```

The equivalent environment variables are:

| Variable | Default | Description |
| --- | --- | --- |
| `PGP_PG_MAJOR_VERSION` | `14` | PostgreSQL major version used when `-v` is omitted. |
| `PGP_INIT_DIR` | None | Initialization directory used when `-i` is omitted; optional. |
| `PGP_CLUSTER_NAME` | `pgpartium` | Name assigned to a locally created cluster. |
| `PGP_CREATE_OPTIONS` | None | Additional options passed when creating the cluster. |
| `NO_CLUSTER` | Unset | When set, install the PostgreSQL runtime without creating a cluster. |

Examples:

```bash
pgp-start -i migrations/initdir
pgp-start -v 17 -i migrations/initdir

PGP_PG_MAJOR_VERSION=17 \
PGP_INIT_DIR=migrations/initdir \
pgp-start

NO_CLUSTER=1 pgp-start
```

Initialization files are processed in sorted order. Executable `.sh` files are run, non-executable `.sh` files are sourced, `.sql` files are passed to `psql`, and `.sql.gz` files are decompressed into `psql`.

## `pgp-make-partitions`

Inspects configured parent and template tables and generates DDL for missing partitions and replicated objects.

```text
OPTIONS:
  -c  Configuration file or directory (default: .)
  -h  Show help
```

Examples:

```bash
pgp-make-partitions -c partition-lifecycle.yaml
pgp-make-partitions -c config/partitions
```

When a directory is supplied, `.yaml` and `.yml` files are processed in sorted path order.

## `pgp-expire-partitions`

Generates detach and/or drop DDL for partitions whose upper bounds are outside the configured retention period.

```text
OPTIONS:
  -c  Configuration file or directory (required)
  -h  Show help
```

Examples:

```bash
pgp-expire-partitions -c partition-lifecycle.yaml
pgp-expire-partitions -c config/partitions
```

Expiration behavior is controlled by `retention`, `detach_only`, `detach_first`, `detach_concurrently`, and `idempotent`. See [Expiration options](configuration.md#expiration-options).

## `pgp-setup-infrastructure`

Installs or refreshes pgpartium's SQL helper functions in the configured database. The lifecycle commands call it automatically.

```text
OPTIONS:
  -h  Show help
```

It uses the same connection defaults and optional `PGP_*` overrides as the lifecycle commands.

## `pgp-get-migration-filename`

Resolves a migration filename template. It is used internally by both lifecycle generators and is available for debugging templates.

```text
OPTIONS:
  -t  Filename template
  -d  Existing migration directory
  -m  Migration description
  -h  Show help
```

Examples:

```bash
pgp-get-migration-filename \
  -t 'V{integer:3}__{description}.sql' \
  -d migrations/partitions \
  -m 'Make partitions for public transactions'
```

See [Output filenames](configuration.md#output-filenames) for every placeholder.

## `gh-create-pr`

Optionally creates or updates a GitHub pull request containing generated repository changes. Migration generation does not depend on this command; users may commit and push locally or publish through another CI/CD system or scheduler.

```text
OPTIONS:
  -b  Branch suffix (default: partition-maintenance)
  -t  Pull-request title (default: chore: partition maintenance)
  -m  Commit message (default: pull-request title)
  -h  Show help
```

`GH_TOKEN` must authenticate an identity allowed to push branches and read/write pull requests. A short-lived dedicated GitHub App token is recommended.

```bash
GH_TOKEN="..." gh-create-pr \
  -b database-partitions \
  -t "chore(db): maintain partitions" \
  -m "chore(db): regenerate partition lifecycle migrations"
```

Behavior:

- exits successfully without Git operations when no tracked or untracked file changed;
- determines the remote default branch;
- resets `pgpartium/<branch>` from the latest remote base;
- commits all repository changes;
- force-updates the dedicated branch;
- creates a PR when none is open;
- updates the body of the existing PR on later runs.

Do not add human commits to the automation branch; change the declarative configuration and rerun reconciliation instead.

See [Automating lifecycle PRs with GitHub Actions](github-actions.md) for App creation and a complete workflow.

## Exit and publication behavior

Both lifecycle generators use a staging directory and handle tables independently.

| Situation | Result |
| --- | --- |
| Every table succeeds | Successful migrations are published; exit `0`. |
| No lifecycle change is needed | No empty migration is published; exit `0`. |
| Some tables succeed and some fail | Successful migrations are published, failures are summarized; exit `1`. |
| A table's SQL generation fails | Its partial file is removed; other tables continue. |
| A table's formatting fails | Its unformatted file is removed; other tables continue. |
| Configuration is invalid | No table processing occurs; exit `1`. |

Multiple successful tables may share one output filename. Their formatted SQL is merged in configuration order. Failed table output is never appended.

Any automation should record both generation exit statuses separately from publication so successful table output can be retained without hiding failures. In GitHub Actions, use `continue-on-error` on generation steps, create or update the PR with successful output, then explicitly fail the job based on the recorded step outcomes. The [GitHub Actions guide](github-actions.md#why-generation-uses-continue-on-error) includes this pattern.
