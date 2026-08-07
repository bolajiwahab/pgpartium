CREATE TABLE test.notifications (created_at timestamptz);

CREATE TABLE test.successful_notifications (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.successful_notifications_2024_12
    PARTITION OF test.successful_notifications
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE test.successful_events (created_at timestamptz)
PARTITION BY RANGE (created_at);

CREATE TABLE test.successful_events_2024_12
    PARTITION OF test.successful_events
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

ALTER SYSTEM SET mock.now = '2025-03-01 00:00:00+00';
