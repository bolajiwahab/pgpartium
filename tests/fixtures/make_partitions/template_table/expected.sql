CREATE TABLE test.test__transactions__2025_03
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_03_transaction_id_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT test__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX
    ON test.test__transactions__2025_03
 USING btree (account_id, status)
 WHERE status = 'active'::text;

CREATE INDEX
    ON test.test__transactions__2025_03
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger('arg');

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON test.test__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE test.test__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
