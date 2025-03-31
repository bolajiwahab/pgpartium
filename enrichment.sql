CREATE TABLE partitions2.public__enrichment__2025_04_01
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE INDEX public__enrichment__2025_04_01_expires_at_idx
    ON partitions2.public__enrichment__2025_04_01
 USING btree (expires_at);

CREATE INDEX public__enrichment__2025_04_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_04_01
 USING btree (created, expires_at);

CREATE INDEX public__enrichment__2025_04_01_expr_expr1_idx
    ON partitions2.public__enrichment__2025_04_01
 USING btree ((data ->> 'user_id'::text), (data -> 'account_id'::text));

CREATE INDEX public__enrichment__2025_04_01_ledger_id_idx
    ON partitions2.public__enrichment__2025_04_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_04_01_ledger_id_idx1
    ON partitions2.public__enrichment__2025_04_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_04_01_ledger_id_idx2
    ON partitions2.public__enrichment__2025_04_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE UNIQUE INDEX public__enrichment__2025_04_01_ledger_id_idx3
    ON partitions2.public__enrichment__2025_04_01
 USING btree (ledger_id);

CREATE TRIGGER prevent_duplicate_acs_transaction_id BEFORE INSERT
    ON partitions2.public__enrichment__2025_04_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_04_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del2 BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_04_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_proc BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_04_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_upd BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_04_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TABLE partitions2.public__enrichment__2025_05_01
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');

CREATE INDEX public__enrichment__2025_05_01_expires_at_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (expires_at);

CREATE INDEX public__enrichment__2025_05_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (created, expires_at);

CREATE INDEX public__enrichment__2025_05_01_expr_expr1_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree ((data ->> 'user_id'::text), (data -> 'account_id'::text));

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx1
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx2
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE UNIQUE INDEX public__enrichment__2025_05_01_ledger_id_idx3
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id);

CREATE TRIGGER prevent_duplicate_acs_transaction_id BEFORE INSERT
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del2 BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_proc BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_upd BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE INDEX public__enrichment__2025_05_01_expires_at_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (expires_at);

CREATE INDEX public__enrichment__2025_05_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (created, expires_at);

CREATE INDEX public__enrichment__2025_05_01_expr_expr1_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree ((data ->> 'user_id'::text), (data -> 'account_id'::text));

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx1
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE INDEX public__enrichment__2025_05_01_ledger_id_idx2
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id) 
 WHERE expires_at > '2025-01-01 00:00:00+00'::timestamp with time zone;

CREATE UNIQUE INDEX public__enrichment__2025_05_01_ledger_id_idx3
    ON partitions2.public__enrichment__2025_05_01
 USING btree (ledger_id);

CREATE TRIGGER prevent_duplicate_acs_transaction_id BEFORE INSERT
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_del2 BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_proc BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

CREATE TRIGGER prevent_duplicate_acs_transaction_id_upd BEFORE INSERT OR DELETE OR UPDATE
    ON partitions2.public__enrichment__2025_05_01
   FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_acs_transaction_id();

