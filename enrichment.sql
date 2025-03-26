CREATE TABLE partitions.enrichment
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2023-01-01 00:00:00+00') TO ('2024-01-01 00:00:00+00');
CREATE TABLE partitions.enrichment
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2024-01-01 00:00:00+00') TO ('2025-01-01 00:00:00+00');
CREATE TABLE partitions.enrichment
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');
CREATE TABLE partitions.enrichment
    PARTITION OF public.enrichment
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');
