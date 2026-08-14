CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE INDEX test__transactions__2025_04_status_idx
        ON test.test__transactions__2025_04 (status)
TABLESPACE pgpartix_fast;
