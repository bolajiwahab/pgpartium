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

## Project Structure

```text
.
├── src
    ├── bin                       # Binaries
    ├── sql                       # Database functions
│── docs                          # Documentation
│── tests                         # Tests
    │── fixtures                  # Test fixtures
        │── expire_partitions     # Expire partitions fixtures
        │── make_partitions       # Make partitions fixtures
    │── migrations                # Schema migrations for tests
        │── dbmate                # Schema migrations for dbmate
        │── flyway                # Schema migrations for flyway
        │── goose                 # Schema migrations for goose
        │── go-migrate            # Schema migrations for go-migrate
    │── spec                      # Shellspec tests
    │── tap                       # pgTap tests
    |── setup.sh                  # Test setup script
│── tools                         # Tools
```

## Architecture

pgpartium has two main components:

1. **The Binaries:** These are the various commands that helps in the generation of migration files for making and expiring partitions.
2. **The Database Functions:** These are the various functions that are used to generate DDL for making and expiring partitions.

## Testing

Test files are located in `tests` directory. There are two different tests: **shellspec** and **pgTap**.

1. **shellspec**: shellspec is used to test the Bash binaries. The tests are located in `tests/spec/`.
2. **pgTap**: pgTap is used to test the database functions. The tests are located in `tests/tap/`.

## Documentation

Schema definition is presented as `html` through [json-schema-for-human](https://pypi.org/project/json-schema-for-humans/). To update the generated html after changes to the underlying schema definition, use:

```bash
./docs/schema_doc_generator.sh
```

The changes can be previewed through a browser.
