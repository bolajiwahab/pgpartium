CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CHECK (status = 'active')
  , UNIQUE (transaction_id, created_at)
  , UNIQUE (account_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , PRIMARY KEY (transaction_id, account_id)
  , UNIQUE (account_id, status)
  , UNIQUE (account_id, created_at)
  , CHECK (round(amount, 2) = amount)
  , CHECK (status = 'active')
);

CREATE UNIQUE INDEX transactions_template_account_status_idx
    ON test.transactions_template (account_id, status)
  WITH (fillfactor = 80, deduplicate_items = false)
 WHERE status = 'active';

CREATE INDEX transactions_template_lower_status_idx
    ON test.transactions_template ((lower(status)));

CREATE FUNCTION test.log_change()
RETURNS trigger
LANGUAGE plpgsql
AS $f$
BEGIN
    RETURN NEW;
END;
$f$;

CREATE TRIGGER suppress_redundant_updates_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger('arg');

CREATE TRIGGER log_change_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE FUNCTION test.log_change();

ALTER TABLE test.transactions_template
    DISABLE TRIGGER log_change_trig;

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
