CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE UNIQUE INDEX
    ON test.test__transactions__2025_04 (account_id, status)
  WITH (fillfactor = '80', deduplicate_items = 'false')
 WHERE status = CAST('active' AS text);

CREATE INDEX
    ON test.test__transactions__2025_04 ((lower(status)));

CREATE TRIGGER suppress_redundant_updates_trig
  BEFORE UPDATE
  ON test.test__transactions__2025_04
  FOR EACH ROW
    EXECUTE PROCEDURE suppress_redundant_updates_trigger('arg');

CREATE TRIGGER suppress_redundant_updates_trig_2
  BEFORE UPDATE
  ON test.test__transactions__2025_04
  FOR EACH ROW
    EXECUTE PROCEDURE suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_04
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
