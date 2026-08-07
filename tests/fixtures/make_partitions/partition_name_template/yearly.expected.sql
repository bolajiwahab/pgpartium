CREATE TABLE test.test__transactions__2025_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');
