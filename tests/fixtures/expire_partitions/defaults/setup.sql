CREATE TABLE test.notifications (
    notification_id uuid NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.test__notifications__2024_12
    PARTITION OF test.notifications
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE test.notifications_2025_01
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE test.test__notifications__2025_02
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

ALTER SYSTEM SET mock.now = '2025-03-01 00:00:00+00';
