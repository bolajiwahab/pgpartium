CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_key UNIQUE (transaction_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

ALTER SYSTEM SET mock.now = '2025-05-01 08:30:00+00';
