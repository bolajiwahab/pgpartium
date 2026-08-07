CREATE TABLE test.test__successful_transactions__2025_04
    PARTITION OF test.successful_transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
