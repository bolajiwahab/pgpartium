CREATE SCHEMA test;

CREATE SCHEMA partitions;

CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_account_id_key UNIQUE (account_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE INDEX transactions_updated_at_idx
    ON test.transactions (updated_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_template_pkey PRIMARY KEY (transaction_id)
  , CONSTRAINT transactions_template_user_id_key UNIQUE (user_id)
  , CONSTRAINT transactions_template_account_id_created_at_key UNIQUE (account_id, created_at)
);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();

ALTER TABLE test.transactions_template
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE INDEX transactions_template_account_id_idx
    ON test.transactions_template (account_id);

CREATE UNIQUE INDEX transactions_template_status_active_key
    ON test.transactions_template (status)
 WHERE status = 'active';

CREATE INDEX transactions_template_updated_at_idx
    ON test.transactions_template (updated_at);
