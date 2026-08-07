CREATE TABLE test.transactions (
    amount numeric NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_2025_04
    PARTITION OF test.transactions (
        CONSTRAINT transactions_2025_04_amount_check CHECK (amount > 0)
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE TABLE test.transactions_default
    PARTITION OF test.transactions (
        CONSTRAINT transactions_default_amount_check CHECK (amount >= 0)
    )
    DEFAULT;

ALTER SYSTEM SET mock.now = '2025-04-15 00:00:00+00';
