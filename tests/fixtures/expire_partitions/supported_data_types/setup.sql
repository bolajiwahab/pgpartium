CREATE TABLE test.expire_by_date (created_at date)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_date_2025_01
    PARTITION OF test.expire_by_date
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE test.expire_by_timestamptz (created_at timestamptz)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_timestamptz_2025_01
    PARTITION OF test.expire_by_timestamptz
    FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-02-01 00:00:00+00');

CREATE TABLE test.expire_by_timestamp (created_at timestamp)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_timestamp_2025_01
    PARTITION OF test.expire_by_timestamp
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2025-02-01 00:00:00');

CREATE TABLE test.expire_by_int4 (created_at int4)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_int4_2025_01
    PARTITION OF test.expire_by_int4
    FOR VALUES FROM (1735689600) TO (1738368000);

CREATE TABLE test.expire_by_int8 (created_at int8)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_int8_2025_01
    PARTITION OF test.expire_by_int8
    FOR VALUES FROM (1735689600000) TO (1738368000000);

CREATE TABLE test.expire_by_uuid (created_at uuid)
PARTITION BY RANGE (created_at);
CREATE TABLE test.expire_by_uuid_2025_01
    PARTITION OF test.expire_by_uuid
    FOR VALUES FROM ('01941f29-7c00-0000-0000-000000000000')
             TO ('0194bece-a000-0000-0000-000000000000');

ALTER SYSTEM SET mock.now = '2025-03-01 00:00:00+00';
