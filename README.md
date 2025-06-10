# pgpartium

**pgpartium** is a tool that helps in managing the creation and expiration of partitions of a PostgreSQL partitioned table. It does this through the generation of migration files for partitions that would be created or dropped.

## Features

- Partition creation and expiration
- Time-based range partitioning
- Partition name templating
- Partition schema
- Constraints, indexes, and triggers definitions replication from a template table
- Highly configurable
- PostgreSQL 13+ supported
- Migration files generation
- Migration file name templating
- Support flyway, go-migrate, dbmate, and goose migration tools
- Pull Requests creation with github action

## Getting Started

**pgpartium** is packaged as a docker [image](https://github.com/bolajiwahab/pgpartium/pkgs/container/pgpartium). The image contains the following utilities:

- **pg-start**: Installs a major PostgreSQL version, optionally initializes a cluster and starts the cluster
- **pgp-migrate**: Applies current schema migrations
- **pgp-make-partitions**: Generates partition migration files according to the configuration
- **pgp-expire-partitions**: Expire partitions according to the configuration

## Installation

```bash
docker pull ghcr.io/bolajiwahab/pgpartium
```

**<span style="color:red">pgpartium is only supported on PostgreSQL 13 or higher</span>**.

## Usage

While you can run **pgp-make-partitions** and **pgp-expire-partitions** separately, you will usually want to run them together. Both require that the schema is already applied to the database, you can either manage the application of the schema yourself, or use **pgp-migrate**. The other necessary piece is the **pg-start** command, which will install a major PostgreSQL version along with the **psql** client, optionally initializes a cluster, and starts the cluster.

For simple usage, run the following command:

```bash
docker run -it --user root --rm --volume "$PWD:/repository" ghcr.io/bolajiwahab/pgpartium:0.5.0 \
    sh -c 'pg-start -v 17 && \
    pgp-migrate -m /repository/migrations -t flyway -v 11.8.0 && \
    pgp-make-partitions -c /repository/partition_config.yaml && \
    pgp-expire-partitions -c /repository/partition_config.yaml'
```

The above command mounts the current directory into the container. Inside the container, it starts Postgres 17, applies the current migrations using Flyway 11.8.0, and then generates migration files to create and expire partitions based on the settings in `partition_config.yaml`. Ensure that the migration directory specified in the partition configuration file matches the mounted directory, in this case `/repository/migrations`. Migration files are then generated in the `/repository/migrations` directory in the container which is mapped to the current directory on the host.

You can substitute flyway and its version in the command above with any of the other supported migration tools.

## Configuration

**pgpartium** expects configuration in form of yaml. For the complete list of configuration options, see [configuration](https://bolajiwahab.github.io/pgpartium/docs/schema.html). For a quick start, see [sample](config.sample.yaml).

Table-level configuration supersedes the global configuration but one of them must be specified for non-default configuration options.

## Contributing

We welcome and greatly appreciate contributions. If you would like to contribute, please see the [contributing guidelines](https://github.com/bolajiwahab/pgpartium/blob/main/docs/docs/contributing.md).

## Support

Encountering issues? Take a look at the existing GitHub [issues](https://github.com/bolajiwahab/pgpartium/issues), and don't hesitate to open a new one.

## License

MIT license.
