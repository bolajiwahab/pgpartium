CREATE TABLE public.public__transactions__2025_03
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_03_status_active_key
    ON public.public__transactions__2025_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_03_account_id_idx
    ON public.public__transactions__2025_03
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_04
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_04_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_04_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_04_status_active_key
    ON public.public__transactions__2025_04
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_04_account_id_idx
    ON public.public__transactions__2025_04
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_04
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_04
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_04
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_05
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_05_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_05_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_05_status_active_key
    ON public.public__transactions__2025_05
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_05_account_id_idx
    ON public.public__transactions__2025_05
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_05
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_05
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_05
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_06
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_06_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_06_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-06-01 00:00:00+00') TO ('2025-07-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_06_status_active_key
    ON public.public__transactions__2025_06
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_06_account_id_idx
    ON public.public__transactions__2025_06
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_06
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_06
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_06
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_07
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_07_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_07_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-07-01 00:00:00+00') TO ('2025-08-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_07_status_active_key
    ON public.public__transactions__2025_07
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_07_account_id_idx
    ON public.public__transactions__2025_07
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_07
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_07
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_07
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_08
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_08_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_08_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-08-01 00:00:00+00') TO ('2025-09-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_08_status_active_key
    ON public.public__transactions__2025_08
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_08_account_id_idx
    ON public.public__transactions__2025_08
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_08
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_08
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_08
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_09
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_09_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_09_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-09-01 00:00:00+00') TO ('2025-10-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_09_status_active_key
    ON public.public__transactions__2025_09
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_09_account_id_idx
    ON public.public__transactions__2025_09
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_09
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_09
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_09
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_10
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_10_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_10_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_10_status_active_key
    ON public.public__transactions__2025_10
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_10_account_id_idx
    ON public.public__transactions__2025_10
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_10
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_10
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_10
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_11
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_11_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_11_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_11_status_active_key
    ON public.public__transactions__2025_11
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_11_account_id_idx
    ON public.public__transactions__2025_11
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_11
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_11
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_11
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2025_12
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2025_12_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2025_12_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2025_12_status_active_key
    ON public.public__transactions__2025_12
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2025_12_account_id_idx
    ON public.public__transactions__2025_12
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2025_12
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2025_12
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2025_12
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2026_01
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2026_01_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2026_01_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-02-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2026_01_status_active_key
    ON public.public__transactions__2026_01
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2026_01_account_id_idx
    ON public.public__transactions__2026_01
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2026_01
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2026_01
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2026_01
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2026_02
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2026_02_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2026_02_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2026-02-01 00:00:00+00') TO ('2026-03-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2026_02_status_active_key
    ON public.public__transactions__2026_02
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2026_02_account_id_idx
    ON public.public__transactions__2026_02
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2026_02
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2026_02
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2026_02
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE TABLE public.public__transactions__2026_03
    PARTITION OF public.transactions (
        CONSTRAINT public__transactions__2026_03_pkey PRIMARY KEY (transaction_id),
        CONSTRAINT public__transactions__2026_03_user_id_key UNIQUE (user_id)
    )
    FOR VALUES FROM ('2026-03-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');

CREATE UNIQUE INDEX public__transactions__2026_03_status_active_key
    ON public.public__transactions__2026_03
 USING btree (status)
 WHERE status = 'active'::text;

CREATE INDEX public__transactions__2026_03_account_id_idx
    ON public.public__transactions__2026_03
 USING btree (account_id);

CREATE TRIGGER suppress_redundant_updates_trig BEFORE UPDATE
    ON public.public__transactions__2026_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

CREATE TRIGGER suppress_redundant_updates_trig_2 BEFORE UPDATE
    ON public.public__transactions__2026_03
   FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();

ALTER TABLE public.public__transactions__2026_03
    DISABLE TRIGGER suppress_redundant_updates_trig_2;
