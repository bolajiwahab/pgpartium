CREATE TABLE test.transactions (
    created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
