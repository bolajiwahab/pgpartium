CREATE TABLE test.events (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.events_2025_01
    PARTITION OF test.events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE test.measurements (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.measurements_2025_01
    PARTITION OF test.measurements
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

ALTER SYSTEM SET mock.now = '2025-03-01 00:00:00+00';
