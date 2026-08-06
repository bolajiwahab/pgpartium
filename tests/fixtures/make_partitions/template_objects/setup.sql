CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
);

CREATE UNIQUE INDEX transactions_template_account_status_idx
    ON test.transactions_template (account_id, status)
  WITH (fillfactor = 80, deduplicate_items = false)
 WHERE status = 'active';

CREATE INDEX transactions_template_lower_status_idx
    ON test.transactions_template ((lower(status)));

CREATE TRIGGER suppress_redundant_updates_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger('arg');

CREATE TRIGGER suppress_redundant_updates_trig_2
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.transactions_template
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
