# Contributing

Thank you for your interest in contributing to pgpartix!.
Contributions are welcome, whether they are bug reports, feature requests, code improvements, documentation updates, or new features. Contributions are welcome in form of Pull Requests. This guide will help you get started with the contributing process.

## Development

**pgpartix** is packaged as a Docker image. The image is built on the Debian Bookworm Slim base and installs PostgreSQL using the official PostgreSQL APT repository. Its development is based on **Bash** and **SQL**. For development, you will also need **pre-commit**.

1. Install **pre-commit**:

    ```console
    python3.12 -m pip install --upgrade pre-commit
    ```

2. Set up git hook scripts

    ```console
    pre-commit install
    ```

## Project structure

```text
.
├── src
│   ├── bin                       # Binaries (pgp-*, gh-create-pr)
│   ├── sql                       # Database functions, numbered by load order
│   ├── schema.json               # JSON Schema for lifecycle configuration files
│   └── createcluster.conf        # Debian pg_createcluster defaults for the image
├── docs                          # Schema doc tooling (schema_doc_generator.sh, schema_doc.yaml)
│   └── docs                      # All published guides (see docs/docs/README.md for the index),
│                                    plus the generated schema.html — this is the GitHub Pages root
├── examples                      # End-to-end configuration examples
├── tests                         # Bats integration tests and fixtures
│   ├── fixtures
│   │   ├── expire_partitions
│   │   ├── make_partitions
│   │   └── initdir               # SQL applied once when the test cluster starts
│   ├── test_make_partitions.sh
│   ├── test_expire_partitions.sh
│   ├── test_get_migration_filename.sh
│   ├── test_setup_infrastructure.sh
│   ├── test_start.sh
│   ├── run-tests.sh              # Builds the test image and runs the suite in Docker
│   ├── run-coverage.sh           # Runs bats under kcov and enforces MIN_COVERAGE
│   └── docker-compose-test.yaml
├── tools                         # Repo maintenance scripts (schema doc freshness check)
└── config.sample.yaml            # Complete annotated configuration reference
```

## Architecture

pgpartix has two main components:

1. **The Binaries:** These are the various commands that helps in the generation of migration files for making and expiring partitions.
2. **The Database Functions:** These are the various functions that are used to generate DDL for making and expiring partitions.

## Testing

Tests are Bats integration tests driven through the public CLI, run inside the project's Docker image against a disposable PostgreSQL cluster. There is no unit-test layer or pgTAP suite; every SQL function is exercised only through the CLI commands that call it.

Each `test_*.sh` file under `tests/` covers one binary. `test_make_partitions.sh` and `test_expire_partitions.sh` additionally auto-discover every fixture directory under `tests/fixtures/{make_partitions,expire_partitions}/` and run it as its own test case, so adding coverage for a new option is usually just adding a fixture, not editing the `.sh` file.

A fixture directory can contain:

| File | Purpose |
| --- | --- |
| `setup.sql` | Optional. Applied before the command runs (schema, tables, template objects, `ALTER SYSTEM SET mock.now = ...`). Requires a matching `teardown.sql`. |
| `teardown.sql` | Drops what `setup.sql` created. Required whenever `setup.sql` is present. |
| `config.yaml` | The lifecycle configuration passed to `-c`. Fixtures with multiple config files (e.g. one per scenario) each get their own `*.expected.sql`, matched by stripping the `.yaml`/`.yml` extension. |
| `config.expected.sql` (or `<name>.expected.sql`) | The exact output the command must produce, including `pgrubic format`'s formatting. |

The test runner diffs the generated file against `*.expected.sql` and then applies the generated SQL to a throwaway database to confirm it is valid, executable DDL - not just textually correct.

`tests/coverage` collects `kcov` output from `run-coverage.sh`, which is what `docker-compose-test.yaml` runs inside the container; `run-tests.sh` is the entry point that builds the image and drives that container.

To run tests, use:

```bash
./tests/run-tests.sh
```

To run tests for a specific postgres version, use:

```bash
PGP_PG_MAJOR_VERSION=<POSTGRES_MAJOR_VERSION> ./tests/run-tests.sh
```

## Documentation

Schema definition is presented as `html` through [json-schema-for-human](https://pypi.org/project/json-schema-for-humans/). To update the generated html after changes to the underlying schema definition, use:

```bash
./docs/schema_doc_generator.sh
```

The changes can be previewed through a browser.
