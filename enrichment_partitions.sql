CREATE TABLE partitions2.public__enrichment__2025_04_01
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE INDEX public__enrichment__2025_04_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_04_01
 USING btree (created, expires_at);

CREATE TABLE partitions2.public__enrichment__2025_05_01
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');

CREATE INDEX public__enrichment__2025_05_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_05_01
 USING btree (created, expires_at);

CREATE TABLE partitions2.public__enrichment__2025_06_01
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    FOR VALUES FROM ('2025-06-01 00:00:00+00') TO ('2025-07-01 00:00:00+00');

CREATE INDEX public__enrichment__2025_06_01_created_expires_at_idx
    ON partitions2.public__enrichment__2025_06_01
 USING btree (created, expires_at);

CREATE TABLE partitions2.enrichment__default
    PARTITION OF public.enrichment (
        CONSTRAINT chk CHECK (1 = 1)
    )
    DEFAULT;

CREATE INDEX enrichment__default_created_expires_at_idx
    ON partitions2.enrichment__default
 USING btree (created, expires_at);

