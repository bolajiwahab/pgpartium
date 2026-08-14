# pgpartix

[![CI](https://github.com/bolajiwahab/pgpartix/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/bolajiwahab/pgpartix/actions/workflows/ci.yaml)
[![release](https://github.com/bolajiwahab/pgpartix/actions/workflows/release.yaml/badge.svg)](https://github.com/bolajiwahab/pgpartix/actions/workflows/release.yaml)

pgpartix is a PostgreSQL partition-lifecycle migration generator. It inspects a PostgreSQL database and writes migrations for partitions that should be created or expired.

pgpartix can be used:

- locally, with generated migration files reviewed and committed by the developer;
- from an existing CI/CD system;
- from a scheduled process on any machine that can reach the database and repository.

The bundled GitHub helper optionally provides a Dependabot- or Renovate-like pull-request experience.

pgpartix only writes migration files. It never applies the generated migrations to a database.

## What it provides

- Creation and expiration DDL from one declarative YAML configuration.
- Configurable future horizons and retention windows.
- Deterministic partition, index, and constraint naming.
- Replication of constraints, indexes, triggers, and storage settings from template tables or existing partitions.
- PostgreSQL date, timestamp, integer epoch, bigint epoch-millisecond, and UUIDv7 partitioning.
- Formatted migration files with [pgrubic](https://bolajiwahab.github.io/pgrubic/), suitable for normal review and deployment.
- Per-table failure isolation: valid output is retained while the command reports failures and exits nonzero.
- Optional GitHub PR reconciliation through the bundled `gh` CLI.
- Support for dedicated, least-privileged GitHub App authentication when that integration is used.
- PostgreSQL 14 and newer.

## How it works

```text
  PostgreSQL schema + lifecycle YAML
                    |
                    v
         pgpartix reconciliation
          /                    \
missing future partitions   expired partitions
           \               /
                    v
          formatted migration files
            /       |       \
           v        v        v
      local Git   CI/CD   scheduled host
            \       |       /
                    v
            review and deploy
```

pgpartix stops at generated migration files. How those files are committed, reviewed, and deployed remains under the user's repository and infrastructure controls.

## Quick start

Pull the image:

```bash
docker pull ghcr.io/bolajiwahab/pgpartix:0.9.0
```

Then run the checked-in [quick-start example](examples/quick-start), which creates an ephemeral PostgreSQL cluster, loads a partitioned table, and generates both creation and expiration migrations:

```bash
docker run --rm \
  --volume "$PWD:/repository" \
  --workdir /repository \
  --env PGP_INIT_DIR=examples/quick-start/initdir \
  ghcr.io/bolajiwahab/pgpartix:0.9.0 \
  bash -lc '
    pgp-start &&
    pgp-run-lifecycle -c examples/quick-start/partition-lifecycle.yaml
  '
```

`pgp-start` defaults to PostgreSQL 14 and supplies the local cluster connection settings. The only database setup input in this example is the initialization directory. It can contain `.sql`, `.sql.gz`, and `.sh` files, including scripts that invoke the application's existing schema or migration tooling. `--workdir /repository` is required because the image otherwise runs from `/src`, while the configuration and output paths are relative to the mounted repository. Generated SQL is written to `examples/quick-start/migrations/pgpartix_output.sql`; apply generated lifecycle migrations only through the application's normal migration process.

See [Getting started](docs/docs/getting-started.md) for external database mode, prerequisites, and output validation.

## Documentation

The [documentation index](docs/docs/README.md) routes each task to a focused guide:

- [Getting started](docs/docs/getting-started.md) - installation, catalog setup, and first generation.
- [Configuration reference](docs/docs/configuration.md) - all creation, expiration, naming, template, storage, and override options.
- [Optional GitHub Actions automation](docs/docs/github-actions.md) - GitHub App setup, short-lived tokens, scheduling, PR reconciliation, security, and troubleshooting.
- [CLI reference](docs/docs/cli-reference.md) - commands, environment variables, examples, and exit behavior.
- [Annotated configuration](config.sample.yaml) - a complete example using the current schema.
- [Generated JSON Schema reference](https://bolajiwahab.github.io/pgpartix/schema.html).

## Included commands

| Command | Purpose |
| --- | --- |
| `pgp-start` | Install PostgreSQL tooling, optionally create a cluster, and apply schema initialization files. |
| `pgp-run-lifecycle` | Generate migrations for missing desired partitions, then detach/drop migrations for expired ones. |
| `pgp-setup-infrastructure` | Install the SQL functions used to inspect and render lifecycle DDL. |
| `pgp-get-migration-filename` | Resolve migration filename templates. |
| `pgp-gh-create-pr` | Optionally create or update a GitHub partition-lifecycle PR. |

Use the [CLI reference](docs/docs/cli-reference.md) for syntax and operational behavior.

## Contributing and support

See the [contributing guide](docs/docs/contributing.md). Use [GitHub issues](https://github.com/bolajiwahab/pgpartix/issues) for bugs, features, and usage questions.

## License

MIT
