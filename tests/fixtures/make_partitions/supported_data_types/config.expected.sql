CREATE TABLE test.test__transactions_by_date__2025_04
    PARTITION OF test.transactions_by_date
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE TABLE test.test__transactions_by_timestamptz__2025_04
    PARTITION OF test.transactions_by_timestamptz
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');

CREATE TABLE test.test__transactions_by_timestamp__2025_04
    PARTITION OF test.transactions_by_timestamp
    FOR VALUES FROM ('2025-04-01 00:00:00') TO ('2025-05-01 00:00:00');

CREATE TABLE test.test__transactions_by_int4__2025_04
    PARTITION OF test.transactions_by_int4
    FOR VALUES FROM ('1743465600') TO ('1746057600');

CREATE TABLE test.test__transactions_by_int8__2025_04
    PARTITION OF test.transactions_by_int8
    FOR VALUES FROM ('1743465600000') TO ('1746057600000');

CREATE TABLE test.test__transactions_by_uuid__2025_04
    PARTITION OF test.transactions_by_uuid
    FOR VALUES FROM ('0195eea5-d400-0000-0000-000000000000') TO ('01968924-9c00-0000-0000-000000000000');
