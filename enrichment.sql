CREATE TABLE partitions.enrichment__2025_03
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    ) FOR VALUES FROM ('2025-03-01 00:00:00+00') TO ('2025-04-01 00:00:00+00')
WITH (fillfactor = '70', autovacuum_enabled = 'true')
TABLESPACE pg_default;

CREATE INDEX enrichment__2025_03_created_expires_at_idx
    ON partitions.enrichment__2025_03
 USING btree (created, expires_at)
TABLESPACE pg_default;

CREATE TABLE partitions.enrichment__2025_04
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    ) FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00')
WITH (fillfactor = '70', autovacuum_enabled = 'true')
TABLESPACE pg_default;

CREATE INDEX enrichment__2025_04_created_expires_at_idx
    ON partitions.enrichment__2025_04
 USING btree (created, expires_at)
TABLESPACE pg_default;
