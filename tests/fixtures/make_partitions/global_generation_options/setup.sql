CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , status text NOT NULL
);

CREATE INDEX transactions_template_status_idx
    ON test.transactions_template (status);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
