CREATE TABLE test.notifications (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
