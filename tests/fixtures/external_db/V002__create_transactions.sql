CREATE TABLE public.transactions (
    transaction_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id, created_at)
)
PARTITION BY RANGE (created_at);
