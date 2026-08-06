CREATE TABLE test.not_partitioned (created_at timestamptz);

CREATE TABLE test.partitioned_by_list (created_at timestamptz)
PARTITION BY LIST (created_at);

CREATE TABLE test.partitioned_by_multiple_columns (
    created_at timestamptz
  , updated_at timestamptz
)
PARTITION BY RANGE (created_at, updated_at);

CREATE TABLE test.partitioned_by_text (created_at text)
PARTITION BY RANGE (created_at);

CREATE TABLE test.invalid_partition_schema (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.invalid_partition_tablespace (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.invalid_index_tablespace (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.zero_interval (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.successful_transactions (created_at timestamptz)
PARTITION BY RANGE (created_at);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
