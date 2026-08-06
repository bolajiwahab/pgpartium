CREATE TABLE test.transactions (created_at timestamptz NOT NULL)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_existing
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-15 00:00:00+00') TO ('2025-04-15 00:00:00+00');

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
