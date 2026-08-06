CREATE TABLE test.accounts (
    account_id uuid PRIMARY KEY
);

CREATE TABLE test.transactions (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , period tstzrange NOT NULL
  , created_at timestamptz NOT NULL
)
PARTITION BY RANGE (created_at);

CREATE TABLE test.transactions_template (
    transaction_id uuid NOT NULL
  , user_id uuid NOT NULL
  , account_id uuid NOT NULL
  , amount numeric NOT NULL
  , period tstzrange NOT NULL
  , created_at timestamptz NOT NULL
  , CONSTRAINT transactions_template_pkey PRIMARY KEY (transaction_id)
  , CONSTRAINT transactions_template_user_id_key UNIQUE (user_id)
  , CONSTRAINT transactions_template_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES test.accounts (account_id)
  , CONSTRAINT transactions_template_amount_check CHECK (amount > 0)
  , CONSTRAINT transactions_template_period_excl EXCLUDE USING gist (period WITH &&)
);

ALTER SYSTEM SET mock.now = '2025-04-01 00:00:00+00';
