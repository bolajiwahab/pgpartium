-- Seed data for testing.
CREATE SCHEMA partitions;

/*
    template table: yes
    initial partitions: 0
    data type: timestamptz
*/
CREATE TABLE public.transactions (
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
    ON public.transactions (updated_at);

CREATE TABLE public.transactions_template (
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

CREATE INDEX transactions_template_account_id_idx
    ON public.transactions_template (account_id);

CREATE UNIQUE INDEX transactions_template_status_active_key
    ON public.transactions_template (status)
 WHERE status = 'active';

CREATE INDEX transactions_template_updated_at_idx
    ON public.transactions_template (updated_at);

/*
    template table: no
    initial partitions: 1
    data type: date
*/
CREATE TABLE public.notifications (
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

CREATE TABLE public.notifications_2025_01
    PARTITION OF public.notifications
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

/*
    template table: no
    initial partitions: 0
    data type: timestamp
*/
CREATE TABLE public.charges (
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
CREATE TABLE public.sales (
    sale_id uuid NOT NULL
  , email text NOT NULL
  , created_at integer NOT NULL
  , updated_at integer NOT NULL
  , CONSTRAINT sales_pkey PRIMARY KEY (sale_id, created_at)
)
PARTITION BY RANGE (created_at);

-- Partitioned by epoch (bigint).
CREATE TABLE public.trips (
    trip_id uuid NOT NULL
  , email text NOT NULL
  , created_at bigint NOT NULL
  , updated_at bigint NOT NULL
  , CONSTRAINT trips_pkey PRIMARY KEY (trip_id, created_at)
)
PARTITION BY RANGE (created_at);

-- Partitioned by List.
CREATE TABLE public.users (
    user_id uuid NOT NULL
  , email text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT users_pkey PRIMARY KEY (user_id)
)
PARTITION BY LIST (user_id);

-- Multi-column partitioned table.
CREATE TABLE public.scheduled_entries (
    scheduled_entry_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at, updated_at);

-- Partitioned by uuid.
CREATE TABLE public.orders (
    order_id uuid NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
)
PARTITION BY RANGE (order_id);

-- Non partitioned table.
CREATE TABLE public.accounts (
    user_id uuid NOT NULL
  , charge_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT accounts_pkey PRIMARY KEY (user_id, created_at)
  , CONSTRAINT accounts_charge_id_key UNIQUE (charge_id)
);
