CREATE TABLE test.test__transactions__2025_05_01
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-05-02 00:00:00+00');
