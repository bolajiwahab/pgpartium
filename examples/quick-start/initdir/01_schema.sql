CREATE TABLE public.transactions (
    transaction_id uuid NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);
