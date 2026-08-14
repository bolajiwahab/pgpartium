# Getting started

pgpartix inspects a PostgreSQL database and writes migration files for missing and expired partitions. It does not apply those lifecycle migrations to the source database. The intended output is a repository change reviewed and deployed through the application's existing migration process.

## Requirements

- PostgreSQL 14 or newer.
- A single-column `RANGE`-partitioned parent table.
- A supported partition key: `date`, `timestamp`, `timestamptz`, `integer`, `bigint`, or UUIDv7-compatible `uuid`.
- An existing directory for generated migration files.
- A database containing the parent tables and any configured schemas, tablespaces, or template tables.

The packaged container supplies PostgreSQL setup utilities, the pgpartix CLIs, pgrubic, Git, and GitHub CLI.

## Install the image

```bash
docker pull ghcr.io/bolajiwahab/pgpartix:0.8.0
```

The container starts as an unprivileged user. `pgp-start` uses passwordless `sudo` internally for the steps that install the requested PostgreSQL packages and create a local cluster, so it does not need to be run as root.

## Run the checked-in example

The repository contains a complete runnable example:

```text
examples/quick-start
├── initdir
│   └── 01_schema.sql
├── migrations
│   └── .gitignore
└── partition-lifecycle.yaml
```

From the repository root, run:

```bash
docker run --rm \
  --volume "$PWD:/repository" \
  --workdir /repository \
  --env PGP_INIT_DIR=examples/quick-start/initdir \
  ghcr.io/bolajiwahab/pgpartix:0.8.0 \
  bash -lc '
    pgp-start &&
    pgp-run-lifecycle -c examples/quick-start/partition-lifecycle.yaml
  '
```

`pgp-start` defaults to PostgreSQL 14 and supplies the local cluster connection settings. `PGP_INIT_DIR` is the only database setup input here and loads the example schema. `--workdir /repository` makes repository-relative configuration and output paths resolve inside the mounted host directory. The generated migration appears at `examples/quick-start/migrations/pgpartix_output.sql` on the host.

To adapt the example, copy its configuration and initialization layout into the application repository. Change `lifecycle.directory`, the configured tables, and the initialization SQL or scripts to match the application's schema migration setup. The output directory must already exist. For all available options, inheritance rules, and naming placeholders, use the [configuration reference](configuration.md) and [annotated sample](../../config.sample.yaml).

## Choose a database source

pgpartix needs an accurate PostgreSQL database. It supports two practical approaches.

### Ephemeral PostgreSQL from repository migrations

This is the recommended mode for local evaluation and automated environments. Provide an initialization directory that recreates the schema pgpartix should inspect.

`pgp-start -i` processes files in lexical order:

- executable or sourceable `.sh` scripts;
- `.sql` files;
- `.sql.gz` files.

The directory is the extension point for recreating the application's schema. It may contain plain or compressed SQL, executable scripts, sourced scripts, or scripts that invoke the application's existing migration tool. This lets each repository bring its own schema setup logic without supplying connection settings for the local cluster.

Example repository layout:

```text
.
├── migrations
│   ├── initdir
│   │   ├── 01_schema.sql
│   │   └── 02_template_tables.sql
│   └── partitions
└── partition-lifecycle.yaml
```

For an application repository, the equivalent command is:

```bash
docker run --rm \
  --volume "$PWD:/repository" \
  --workdir /repository \
  --env PGP_INIT_DIR=migrations/initdir \
  ghcr.io/bolajiwahab/pgpartix:0.8.0 \
  bash -lc '
    pgp-start &&
    pgp-run-lifecycle -c partition-lifecycle.yaml
  '
```

The generated SQL appears in `migrations/partitions` on the host.

### Existing external database

Use an existing non-production database when it is the authoritative representation of the schema. Install only the PostgreSQL client runtime, then supply connection settings:

```bash
docker run --rm \
  --volume "$PWD:/repository" \
  --workdir /repository \
  --env PGP_PG_MAJOR_VERSION=17 \
  --env NO_CLUSTER=1 \
  --env PGP_USER="$PGP_USER" \
  --env PGP_PASSWORD="$PGP_PASSWORD" \
  --env PGP_HOST="$PGP_HOST" \
  --env PGP_PORT="$PGP_PORT" \
  --env PGP_DATABASE="$PGP_DATABASE" \
  ghcr.io/bolajiwahab/pgpartix:0.8.0 \
  bash -lc '
    pgp-start &&
    pgp-run-lifecycle -c partition-lifecycle.yaml
  '
```

The connection role must be able to inspect the application catalog, creates a dedicated schema `pgpartix` for the helper objects, and create or replace helper objects in the `pgpartix` schema. Prefer a non-production database and restrict network and credential access appropriately.

## Review the output

`pgp-run-lifecycle` produces DDL for missing desired ranges, then detach and/or drop DDL for ranges outside the retention period.

Before applying generated migrations:

1. Review partition bounds and names.
2. Review every detach or drop operation.
3. Run the repository's SQL formatter and linter if additional rules apply.
4. Execute migrations against a disposable database.
5. Deploy them through the existing migration process.

pgpartix formats each table independently. If one table fails, valid output from other tables is retained, the failed table's partial output is removed, and the command exits nonzero.

## Choose how to publish the result

Generated migrations are ordinary repository files. pgpartix does not require a particular Git provider or publication workflow. Common operating models include:

- run locally, review the files, then use the normal `git add`, `git commit`, and `git push` workflow;
- invoke the lifecycle commands from an existing GitHub, GitLab, Jenkins, or other CI/CD pipeline;
- schedule a script with cron, a systemd timer, or an infrastructure scheduler on a VM or runner, then commit and push using that environment's credentials;
- use the bundled GitHub helper to maintain a dedicated pull request automatically.

Whichever model is used, preserve the generator exit status. The lifecycle command can publish valid files for successful tables and still exit nonzero because another table failed. Review or publish the successful files as appropriate, while keeping the overall run visibly failed for operator attention.

## Optional GitHub automation

After local generation is stable, the [GitHub Actions guide](github-actions.md) provides one ready-made scheduling and publication option. It explains how to create a least-privileged GitHub App and use the bundled `pgp-gh-create-pr` command to create or refresh a lifecycle PR. The lifecycle generator itself remains independent of GitHub and can be wrapped by other providers or infrastructure.

For command syntax and environment variables, see the [CLI reference](cli-reference.md).
