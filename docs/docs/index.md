# pgpartix documentation

pgpartix generates reviewable PostgreSQL partition-lifecycle migrations. Users can commit them locally, integrate them with any CI/CD or scheduling environment, or use the optional GitHub pull-request helper.

## Start here

1. [Getting started](getting-started.md) - install the container, prepare a schema catalog, and generate the first migrations.
2. [Configuration reference](configuration.md) - configure partition creation, expiration, naming, templates, storage, and table overrides.
3. [Optional GitHub Actions automation](github-actions.md) - run reconciliation on a GitHub schedule and create PRs through a dedicated GitHub App.

## Reference

- [CLI reference](cli-reference.md) - commands, environment variables, exit behavior, and examples.
- [Annotated configuration](config.sample.yaml) - a complete configuration using the current schema.
- [Generated JSON Schema reference](schema.html) - machine-derived option documentation.
- [Contributing](contributing.md) - development environment, testing, and contribution workflow.

## Documentation boundaries

Each guide has one purpose:

| Guide | Use it when |
| --- | --- |
| [Getting started](getting-started.md) | You are evaluating or installing pgpartix. |
| [Configuration](configuration.md) | You need to understand or change lifecycle behavior. |
| [GitHub Actions](github-actions.md) | You want the optional scheduled GitHub PR workflow. |
| [CLI reference](cli-reference.md) | You need command syntax, environment requirements, or failure semantics. |
