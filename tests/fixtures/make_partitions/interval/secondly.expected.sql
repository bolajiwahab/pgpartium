CREATE TABLE test.test__transactions__2025_04_01_00_00_00
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-04-01 00:00:01+00');
