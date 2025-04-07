-- 1. Partitioned tables by timestamptz
/*
    template table: no
    initial partitions: 0
    interval: 1 month
    name template: '{schema}__{table}__YYYY_MM'
    past: 0
    future: 2
    expected partitions: 2
*/
CREATE TABLE public.transactions (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id, created_at)
) PARTITION BY RANGE (created_at);

/*
    template table: no
    initial partitions: 1
    interval: 1 month
    name template: '{schema}__{table}__YYYY_MM'
    past: 1
    future: 2
    expected partitions: 4
*/
CREATE TABLE public.notifications (
    notification_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , content text NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT notifications_pkey PRIMARY KEY (notification_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE public.transactions_2025_01 PARTITION OF public.transactions
   FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2025-02-01 00:00:00+00');

/*
    template table: yes
    initial partitions: 0
    interval: 1 month
    name template: '{schema}__{table}__YYYY_MM'
    past: 1
    future: 2
    expected partitions: 3
*/
/* Partitioned table with template table, no partitions */
CREATE TABLE public.charges (
    charge_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT charge_pkey PRIMARY KEY (charge_id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE public.charges_template (
    charge_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , status text NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT charges_template_pkey PRIMARY KEY (charge_id, created_at)
  , CONSTRAINT charges_template_user_id_key UNIQUE (user_id)
);

CREATE INDEX charges_template_account_id_idx
    ON public.charges_template (account_id);

CREATE INDEX charges_template_status_active_idx
    ON public.charges_template (status)
 WHERE status = 'active';

---- Partitioned by List
CREATE TABLE public.users (
    user_id uuid NOT NULL
  , name text NOT NULL
  , email text NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
  , CONSTRAINT users_pkey PRIMARY KEY (user_id)
) PARTITION BY LIST (user_id);

-- Multi-column partitioned table
CREATE TABLE public.scheduled_entries (
    scheduled_entry_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
) PARTITION BY RANGE (created_at, updated_at);

-- Partitioned by uuid
CREATE TABLE public.orders (
    order_id uuid NOT NULL
  , user_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , updated_at timestamptz NOT NULL
) PARTITION BY RANGE (order_id);
