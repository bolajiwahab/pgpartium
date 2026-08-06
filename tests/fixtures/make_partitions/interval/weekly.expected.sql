CREATE TABLE test.test__transactions__2025_14
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-03-31 00:00:00+00') TO ('2025-04-07 00:00:00+00');
