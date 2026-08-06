CREATE TABLE test.transactions_by_date (
    created_at date
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_by_timestamptz (
    created_at timestamptz
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_by_timestamp (
    created_at timestamp
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_by_int4 (
    created_at int4
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_by_int8 (
    created_at int8
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_by_uuid (
    created_at uuid
)
PARTITION BY RANGE (created_at);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
