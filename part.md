# Partitioning

Partitioning is a database design technique where a potentially large table is broken into smaller sub-tables. These sub-tables are called partitions of the main table.

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/rvvq44uf1attc7z0nm1y.png)

There are reasons a table might be partitioned, few of which include:

- Query performance
- Ease of maintenance
- Data retention and archival

Partitioning is transparent, the application does not need to know about the partitions, it simply interacts with the main table as it would if the table was not partitioned. This is called **declarative partitioning**, which was introduced in PostgreSQL 10.

As mentioned previously, partitions are themselves tables. This means that they can also be partitioned, this is what is called sub-partitioning: partitioning a partition of a main table.

To partition a table, we need a key column or a set of columns. While you can partition a table on multiple columns, it can easily become a nightmare to get partition pruning right. If you find yourself needing to partition a table on multiple columns, consider sub-partitioning.

Partition pruning is a query optimization technique that optimizes query performance by excluding (prunes) unnecessary partitions during query planning and execution base on the query’s WHERE clause.

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/c8ubp69984n1oxdolzce.png)

Declarative partitioning in PostgreSQL supports 3 in-built strategies:

- Range partitioning
- List partitioning
- Hash partitioning

## Range Partitioning

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/7f38recg2g25xo7xys0t.png)

In range partitioning, the main table is partitioned into ranges of values, with no overlaps of ranges of values assigned to the different partitions. Each partition holds a specific range, with inclusive lower bound and exclusive upper bound. Range partitioning is most common with time-series data.

When a table is partitioned on a timestamp column, the interval between the lower bound and upper bound of the partitions is usually called **resolution**. Common resolutions include:

- Hour
- Day
- Month
- Year

While you can have mixtures of resolution in a partition tree, it is recommended to have your partitions have the same resolution.

## List Partitioning

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/xmymigp5twjsa4yy1lvu.png)

In list partitioning, the table is partitioned based on values of key column(s). Unlike range partitioning, which is based on ranges of values, the partitions here are based on distinct values of the key column(s).

### Hash Partitioning

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/apjkw3u14mxrav2062ef.png)

In hash partitioning, the table is partitioned based on the hash value of the key column(s). Hash partitioning uses a hash function to evenly distribute data across number of partitions. Hash partitioning shines especially when data is not ordered.

## Global Uniqueness

PostgreSQL does not yet support global uniqueness across a partition tree, but we can enforce uniqueness in each partition.

To enforce per partition uniqueness, we have two options:

1. We can simply add a unique or primary key constraint to each partition directly, but we will always need to add such constraint to future partitions as well.
2. The other option is to add such constraint to the main table which will automatically propagate to all current and future partitions, but this comes with certain limitations:

    > To create a unique or primary key constraint on a partitioned table, the partition keys must not include any expressions or function calls and the constraint's columns must include all the partition key columns. This limitation exists because the individual indexes making up the constraint can only directly enforce uniqueness within their own partitions; therefore, the partition structure itself must guarantee that there are not duplicates in different partitions.

    This means that if the partition key column(s) are not initially part of your unique or primary key, their values must be constant within each partition. Let's do some tests, we will be using range partitioning.

    a. Create partitioned table

    ```sql
    CREATE TABLE public.test (
        test_id uuid NOT NULL
      , account_id uuid NOT NULL
      , status int NOT NULL
      , created_at timestamptz NOT NULL
      , updated_at timestamptz NOT NULL
      , CONSTRAINT test_pkey PRIMARY KEY (test_id, created_at)
    ) PARTITION BY RANGE (created_at);
    ```

    b. Add a partition, with **monthly** resolution

    ```sql
    CREATE TABLE public.test_2025_03
        PARTITION OF public.test
        FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');
    ```

    c. Insert some data

    ```sql
    INSERT INTO public.test (test_id, account_id, status, created_at, updated_at)
    VALUES ('78c361e7-f60d-4293-b709-6f9a6366e84e', gen_random_uuid(), 1, '2025-03-15 20:12:24.215871+00', '2025-03-15 20:12:24.215871+00');
    ```

    d. Let us try and insert same **test_id** again

    ```sql
    INSERT INTO public.test (test_id, account_id, status, created_at, updated_at)
    VALUES ('78c361e7-f60d-4293-b709-6f9a6366e84e', gen_random_uuid(), 1, '2025-03-15 20:12:57.727486+00', '2025-03-15 20:12:57.727486+00');
    ```

    e. We do not get an error, let us confirm the location of the rows

    ```sql
    SELECT tableoid::regclass AS partition
         , test_id
         , account_id
         , status
         , created_at
         , updated_at
      FROM public.test
     WHERE test_id = '78c361e7-f60d-4293-b709-6f9a6366e84e';
    ```

    We have this

    ```console
       tableoid   |               test_id                |              account_id              | status |          created_at           |          updated_at

    --------------+--------------------------------------+--------------------------------------+--------+-------------------------------+-------------------------------
    test_2025_03 | 78c361e7-f60d-4293-b709-6f9a6366e84e | 1ff277f8-e16c-4de9-b10d-0a9c2a1cca37 |      1 | 2025-03-15 20:12:24.215871+01 | 2025-03-15 20:12:24.215871+01
    test_2025_03 | 78c361e7-f60d-4293-b709-6f9a6366e84e | ba467fa3-f135-420f-bf40-96aab62dd8f9 |      1 | 2025-03-15 20:12:57.727486+01 | 2025-03-15 20:12:57.727486+01
    (2 rows)

    ```

    This is because our partition key `created_at` which is now part of our primary key is different for the second insert even if the difference is in milliseconds, rendering our primary key useless. To circumvent this, we need to have a constant value for `created_at` for each partition.

    f. Let us adjust our partitioning

    ```sql
    DROP TABLE public.test;

    CREATE TABLE public.test (
        partition_date date NOT NULL
      , test_id uuid NOT NULL
      , account_id uuid NOT NULL
      , status int NOT NULL
      , created_at timestamptz NOT NULL
      , updated_at timestamptz NOT NULL
      , CONSTRAINT test_pkey PRIMARY KEY (test_id, partition_date)
    ) PARTITION BY RANGE (partition_date);
    ```

    We have now added a new column `partition_date`, which we have now partitioned the table on.

    g. Add a partition, with **monthly** resolution

    ```sql
    CREATE TABLE public.test_2025_03
        PARTITION OF public.test
        FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
    ```

    h. Insert some data

    ```sql
    INSERT INTO public.test (partition_date, test_id, account_id, status, created_at, updated_at)
    VALUES ('2025-03-15 20:12:24.215871+00', '78c361e7-f60d-4293-b709-6f9a6366e84e', gen_random_uuid(), 1, '2025-03-15 20:12:24.215871+00', '2025-03-15 20:12:24.215871+00');
    ```

    i. Let us try and insert same **test_id** again

    ```sql
    INSERT INTO public.test (partition_date, test_id, account_id, status, created_at, updated_at)
    VALUES ('2025-03-15 20:12:57.727486+00', '78c361e7-f60d-4293-b709-6f9a6366e84e', gen_random_uuid(), 1, '2025-03-15 20:12:57.727486+00', '2025-03-15 20:12:57.727486+00');
    ```

    We got this error:

    ```console
    ERROR:  duplicate key value violates unique constraint "test_2025_03_pkey"
    DETAIL:  Key (test_id, partition_date)=(78c361e7-f60d-4293-b709-6f9a6366e84e, 2025-03-15) already exists.
    ```

    j. Now that we are able to ensure that our main primary key (**test_id**) is unique for each partition, remember that the partition resolution is **monthly**, and we can have different dates in a month and thus different `partition_date` values, rendering our primary key useless once more.

    ```sql
    INSERT INTO public.test (partition_date, test_id, account_id, status, created_at, updated_at)
    VALUES ('2025-03-15 20:12:57.727486+00', '78c361e7-f60d-4293-b709-6f9a6366e84e', gen_random_uuid(), 1, '2025-03-15 20:12:57.727486+00', '2025-03-15 20:12:57.727486+00');
    ```

    This means that uniqueness within each partition is dependent on the resolution of the partitioning.

## Limitations of partitioning in PostgreSQL
