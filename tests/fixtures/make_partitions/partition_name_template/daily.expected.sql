CREATE TABLE test.test__transactions__2025_04_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-04-02 00:00:00+00');
