CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_04_pkey PRIMARY KEY (transaction_id, account_id)
      , CONSTRAINT test__transactions__2025_04_account_id_status_key UNIQUE (account_id, status)
      , CONSTRAINT test__transactions__2025_04_amount_check CHECK (round(amount, 2) = amount)
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE UNIQUE INDEX test__transactions__2025_04_account_id_status_idx
    ON test.test__transactions__2025_04 (account_id, status)
  WITH (fillfactor = '80', deduplicate_items = 'false')
 WHERE status = CAST('active' AS text);

CREATE INDEX test__transactions__2025_04_expr_idx
    ON test.test__transactions__2025_04 ((lower(status)));

CREATE TRIGGER test__transactions__2025_04_log_change
  BEFORE UPDATE
  ON test.test__transactions__2025_04
  FOR EACH ROW
    EXECUTE PROCEDURE test.log_change();

ALTER TABLE test.test__transactions__2025_04
    DISABLE TRIGGER test__transactions__2025_04_log_change;

CREATE TRIGGER test__transactions__2025_04_suppress_redundant_updates_trigger
  BEFORE UPDATE
  ON test.test__transactions__2025_04
  FOR EACH ROW
    EXECUTE PROCEDURE suppress_redundant_updates_trigger('arg');
