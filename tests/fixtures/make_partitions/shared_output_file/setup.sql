CREATE TABLE test.events (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.measurements (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
