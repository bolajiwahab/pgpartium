CREATE TABLE public.loan (
    loan_id uuid NOT NULL
  , transaction_id uuid NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT loan_transaction_id_created_at_fkey FOREIGN KEY (transaction_id, created_at)
        REFERENCES public.transactions (transaction_id, created_at)
)
PARTITION BY RANGE (created_at);
