-- Seed data for testing.
CREATE SCHEMA IF NOT EXISTS test;

CREATE SCHEMA IF NOT EXISTS partitions;

/*
    template table: yes
    initial partitions: 0
    data type: timestamptz
*/
CREATE TABLE IF NOT EXISTS test.transactions (
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

CREATE INDEX IF NOT EXISTS transactions_updated_at_idx
    ON test.transactions (updated_at);

CREATE TABLE IF NOT EXISTS test.transactions_template (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_template_pkey PRIMARY KEY (transaction_id)
  , CONSTRAINT transactions_template_user_id_key UNIQUE (user_id)
  , CONSTRAINT transactions_template_account_id_created_at_key UNIQUE (account_id, created_at)
);

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();

CREATE OR REPLACE TRIGGER suppress_redundant_updates_trig_2
    BEFORE UPDATE ON test.transactions_template
    FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();

ALTER TABLE IF EXISTS test.transactions_template
    DISABLE TRIGGER suppress_redundant_updates_trig_2;

CREATE INDEX IF NOT EXISTS transactions_template_account_id_idx
    ON test.transactions_template (account_id);

CREATE UNIQUE INDEX IF NOT EXISTS transactions_template_status_active_key
    ON test.transactions_template (status)
 WHERE status = 'active';

CREATE INDEX IF NOT EXISTS transactions_template_updated_at_idx
    ON test.transactions_template (updated_at);

/*
    template table: no
    initial partitions: 1
    data type: date
*/
CREATE TABLE IF NOT EXISTS test.notifications (
    notification_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , content text NOT NULL
  , status text NOT NULL
  , created_at date NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT notifications_pkey PRIMARY KEY (notification_id, created_at)
)
PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS test.notifications_2025_01
    PARTITION OF test.notifications
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

/*
    template table: no
    initial partitions: 0
    data type: timestamp
*/
CREATE TABLE IF NOT EXISTS test.charges (
    charge_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , content text NOT NULL
  , status text NOT NULL
  , created_at timestamp NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT charges_pkey PRIMARY KEY (charge_id, created_at)
)
PARTITION BY RANGE (created_at);

-- Partitioned by epoch (integer).
CREATE TABLE IF NOT EXISTS test.sales (
    sale_id uuid NOT NULL
  , email text NOT NULL
  , created_at integer NOT NULL
  , updated_at integer NOT NULL
  , CONSTRAINT sales_pkey PRIMARY KEY (sale_id, created_at)
)
PARTITION BY RANGE (created_at);

-- Partitioned by epoch (bigint).
CREATE TABLE IF NOT EXISTS test.trips (
    trip_id uuid NOT NULL
  , email text NOT NULL
  , created_at bigint NOT NULL
  , updated_at bigint NOT NULL
  , CONSTRAINT trips_pkey PRIMARY KEY (trip_id, created_at)
)
PARTITION BY RANGE (created_at);

-- Partitioned by List.
CREATE TABLE IF NOT EXISTS test.users (
    user_id uuid NOT NULL
  , email text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT users_pkey PRIMARY KEY (user_id)
)
PARTITION BY LIST (user_id);

-- Multi-column partitioned table.
CREATE TABLE IF NOT EXISTS test.scheduled_entries (
    scheduled_entry_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at, updated_at);

-- Partitioned by uuid.
CREATE TABLE IF NOT EXISTS test.orders (
    order_id uuid NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (order_id);

-- Partitioned by text.
CREATE TABLE IF NOT EXISTS test.books (
    book_id text NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (book_id);

-- Non partitioned table.
CREATE TABLE IF NOT EXISTS test.accounts (
    user_id uuid NOT NULL
  , charge_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT accounts_pkey PRIMARY KEY (user_id, created_at)
  , CONSTRAINT accounts_charge_id_key UNIQUE (charge_id)
);
