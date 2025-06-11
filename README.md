# pgpartium

**pgpartium** is a tool that helps in managing the creation and expiration of partitions of a PostgreSQL partitioned table. It does this through the generation of migration files for partitions that would be created or dropped.

## Features

- Partition creation and expiration
- Time-based range partitioning
- Partition name templating
- Partition schema
- Partition tablespace
- Index tablespace
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
- **gh-create-pr**: Creates a pull request on github with generated migration files

## Installation

```bash
docker pull ghcr.io/bolajiwahab/pgpartium:0.5.0
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

## Binaries

### pg-start

Installs a major PostgreSQL version along with psql client, optionally initializes a cluster and starts the cluster.

By default, it creates a cluster with `pg_createcluster` and starts the cluster.

```bash
pg-start

Installs major PostgreSQL version and psql client, optionally creates a cluster and starts the cluster.

OPTIONS:
  -v  the postgres version to use (Required)
  -h  show this help message.

SAMPLE USAGE:
    pg-start -v 17
```

To skip initialising a cluster, use

```bash
NO_CLUSTER=1 pg-start -v 17
```

### pgp-migrate

Applies current schema migrations. It requires the directory of the migration files, the migration tool and its version. There are currently 4 supported migration tools: **flyway**, **go-migrate**, **dbmate**, and **goose**. It also supports passing the connection details to the database to use if you are not using the default database created by **pg-start**.

```bash
pgp-migrate

Apply schema migrations.

OPTIONS:
  -m  the directory to the migration files (Required)
  -t  the migration tool (Required)
  -v  the migration tool version (Required)
  -u  the database username (Default: postgres)
  -w  the database password (Default: postgres)
  -s  the database host (Default: localhost)
  -p  the database port (Default: 5432)
  -d  the database name (Default: postgres)
  -h  show this help message.

SAMPLE USAGE:
    pgp-migrate -m "migrations" -t flyway -v 11.8.0
    pgp-migrate -m "migrations" -t flyway -v 11.8.0 -u user -w password -s host -p port -d database
```

You will not need **pgp-migrate** if you are managing the migration of the schema yourself.

### pgp-make-partitions

Creates migration files to create partitions for partitioned tables. It requires the config file in yaml. It also supports passing the connection details to the database to use if you are not using the default database created by **pg-start**.

```bash
pgp-make-partitions

Creates migration files to create partitions for partitioned tables.

OPTIONS:
  -c  the config file in yaml (Required)
  -u  the database username (Default: postgres)
  -w  the database password (Default: postgres)
  -s  the database host (Default: localhost)
  -p  the database port (Default: 5432)
  -d  the database name (Default: postgres)
  -h  show this help message.

SAMPLE USAGE:
    pgp-make-partitions -c config.yaml
    pgp-make-partitions -c config.yaml -u user -w password -s host -p port -d database
```

### pgp-expire-partitions

Creates migration files to expire partitions for partitioned tables. It requires the config file in yaml. It also supports passing the connection details to the database to use if you are not using the default database created by **pg-start**.

```bash
pgp-expire-partitions

Creates migration files to expire partitions for partitioned tables.

OPTIONS:
  -c  the config file in yaml (Required)
  -u  the database username (Default: postgres)
  -w  the database password (Default: postgres)
  -s  the database host (Default: localhost)
  -p  the database port (Default: 5432)
  -d  the database name (Default: postgres)
  -h  show this help message.

SAMPLE USAGE:
    pgp-expire-partitions -c config.yaml
    pgp-expire-partitions -c config.yaml -u user -w password -s host -p port -d database
```

## gh-create-pr

A helper script to creates or updates a pull request on github with the migration files generated by **pgp-make-partitions** and **pgp-expire-partitions**.

```bash
gh-create-pr

Creates or updates a pull request on github.

OPTIONS:
  -b  the branch name to use (Default: partition-maintenance)
  -t  the title of the pull request (Default: chore: partition maintenance)
  -m  the commit message (Default: chore: partition maintenance)
  -h  show this help message.

SAMPLE USAGE:
    gh-create-pr -b generate-partitions
```

## Contributing

We welcome and greatly appreciate contributions. If you would like to contribute, please see the [contributing guidelines](docs/docs/contributing.md).

## Support

Encountering issues? Take a look at the existing GitHub [issues](https://github.com/bolajiwahab/pgpartium/issues), and don't hesitate to open a new one.

## License

MIT license.
