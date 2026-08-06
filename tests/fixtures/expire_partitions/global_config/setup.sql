CREATE TABLE test.inherited_events (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.inherited_events_2024_12
    PARTITION OF test.inherited_events
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE test.overridden_events (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.overridden_events_2024_12
    PARTITION OF test.overridden_events
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

ALTER SYSTEM SET mock.now = '2025-03-01 00:00:00+00';
