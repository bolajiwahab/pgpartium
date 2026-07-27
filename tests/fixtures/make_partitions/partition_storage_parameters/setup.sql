CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_key UNIQUE (transaction_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , status text NOT NULL
)
WITH (autovacuum_enabled=FALSE, fillfactor=90, vacuum_index_cleanup=OFF, toast.vacuum_truncate = FALSE, toast.vacuum_index_cleanup = OFF);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
