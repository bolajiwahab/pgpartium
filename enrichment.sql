CREATE TABLE partitions2.public__enrichment__2023_01_01
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2023-01-01 00:00:00+00') TO ('2024-01-01 00:00:00+00');

CREATE TABLE partitions2.public__enrichment__2024_01_01
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2024-01-01 00:00:00+00') TO ('2025-01-01 00:00:00+00');

CREATE TABLE partitions2.public__enrichment__2025_01_01
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');

CREATE TABLE partitions2.public__enrichment__2026_01_01
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');

CREATE TABLE partitions2.enrichment__default
    PARTITION OF public.enrichment
    DEFAULT;

