CREATE TABLE test.test__transactions__2025_05
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_05_amount_check CHECK (amount > CAST(0 AS numeric))
    )
    FOR VALUES FROM ('2025-05-01 00:00:00+00') TO ('2025-06-01 00:00:00+00');
