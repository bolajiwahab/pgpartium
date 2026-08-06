# Contributing

Thank you for your interest in contributing to pgpartium!.
Contributions are welcome, whether they are bug reports, feature requests, code improvements, documentation updates, or new features. Contributions are welcome in form of Pull Requests. This guide will help you get started with the contributing process.

## Development

**pgpartium** is packaged as a Docker image. The image is built on the Debian Bookworm Slim base and installs PostgreSQL using the official PostgreSQL APT repository. Its development is based on **Bash** and **SQL**. For development, you will also need **pre-commit**.

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
    ├── bin                       # Binaries
    ├── sql                       # Database functions
│── docs                          # Documentation
│── tests                         # Bats integration tests and fixtures
    │── fixtures
        │── expire_partitions
        │── make_partitions
    │── test_expire_partitions.sh
    │── test_make_partitions.sh
    │── run-tests.sh
│── tools                         # Tools
```

## Architecture

pgpartium has two main components:

1. **The Binaries:** These are the various commands that helps in the generation of migration files for making and expiring partitions.
2. **The Database Functions:** These are the various functions that are used to generate DDL for making and expiring partitions.

## Testing

Tests are Bats integration tests driven through the public CLI. Their fixtures initialize real PostgreSQL objects, generate migrations, compare expected SQL, and execute generated SQL against disposable databases. This keeps command behavior and the SQL functions behind it covered through the same entry point users run.

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
