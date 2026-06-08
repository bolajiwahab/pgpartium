CREATE SCHEMA test;

CREATE SCHEMA partitions;

CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_account_id_key UNIQUE (account_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE INDEX transactions_updated_at_idx
    ON test.transactions (updated_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_template_pkey PRIMARY KEY (transaction_id)
  , CONSTRAINT transactions_template_user_id_key UNIQUE (user_id)
  , CONSTRAINT transactions_template_account_id_created_at_key UNIQUE (account_id, created_at)
)
WITH (autovacuum_enabled=FALSE, fillfactor=100, toast.vacuum_truncate = FALSE)
TABLESPACE pg_default;

CREATE INDEX transactions_template_account_id_idx
    ON test.transactions_template (account_id)
TABLESPACE pgpartium_fast;

CREATE UNIQUE INDEX transactions_template_account_id_status_active_key
    ON test.transactions_template (account_id, status)
WITH (fillfactor=80, deduplicate_items = FALSE)
 WHERE status = 'active';

CREATE INDEX transactions_template_updated_at_idx
    ON test.transactions_template (updated_at);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger('arg');

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();

ALTER TABLE test.transactions_template
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

-- Partitioned by List.
CREATE TABLE test.users (
    user_id uuid NOT NULL
  , email text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT users_pkey PRIMARY KEY (user_id)
)
PARTITION BY LIST (user_id);

-- Multi-column partitioned table.
CREATE TABLE test.scheduled_entries (
    scheduled_entry_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at, updated_at);

-- Partitioned by uuid.
CREATE TABLE test.orders (
    order_id uuid NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (order_id);

-- Partitioned by unsupported data type - text.
CREATE TABLE test.books (
    book_id text NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (book_id);

-- Non partitioned table.
CREATE TABLE test.accounts (
    user_id uuid NOT NULL
  , charge_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT accounts_pkey PRIMARY KEY (user_id, created_at)
  , CONSTRAINT accounts_charge_id_key UNIQUE (charge_id)
);

CREATE TABLE test.notifications (
    notification_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , content text NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT notifications_pkey PRIMARY KEY (notification_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.test__notifications__2024_12
    PARTITION OF test.notifications
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE test.notifications_2025_01
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE test.test__notifications__2025_02
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE test.test__notifications__2025_03
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- partitioned by date
CREATE TABLE test.transactions_by_date (
    date date
  , amount numeric
  , created_on date
)
PARTITION BY RANGE (created_on);

-- partitioned by timestamptz
CREATE TABLE test.transactions_by_timestamptz (
    created_at timestamptz
  , amount numeric
)
PARTITION BY RANGE (created_at);

-- partitioned by timestamp
CREATE TABLE test.transactions_by_timestamp (
    created_at timestamp
  , amount numeric
)
PARTITION BY RANGE (created_at);

-- partitioned by int4 (int)
CREATE TABLE test.transactions_by_int4 (
    created_at int4
  , amount numeric
)
PARTITION BY RANGE (created_at);

-- partitioned by int8 (bigint)
CREATE TABLE test.transactions_by_int8 (
    created_at int8
  , amount numeric
)
PARTITION BY RANGE (created_at);

-- partitioned by uuidv7
CREATE TABLE test.transactions_by_uuidv7 (
    created_at uuid
  , amount numeric
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.messages (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamp NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT messages_account_id_key UNIQUE (account_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.test__messages__2024_12
    PARTITION OF test.messages
    FOR VALUES FROM ('2024-12-01 00:00:00') TO ('2025-01-01 00:00:00');

CREATE TABLE test.test__messages__2025_01
    PARTITION OF test.messages
    FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2025-02-01 00:00:00');

CREATE TABLE test.test__messages__2025_02
    PARTITION OF test.messages
    FOR VALUES FROM ('2025-02-01 00:00:00') TO ('2025-03-01 00:00:00');
