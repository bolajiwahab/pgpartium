CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions (
    CONSTRAINT test__transactions__2025_04_custom_pkey PRIMARY KEY (transaction_id)
  , CONSTRAINT test__transactions__2025_04_generic_user_id_key UNIQUE (user_id)
  , CONSTRAINT test__transactions__2025_04_generic_account_id_fkey FOREIGN KEY (account_id) REFERENCES test.accounts (account_id)
  , CONSTRAINT test__transactions__2025_04_generic_amount_check CHECK (amount > CAST(0 AS numeric))
  , CONSTRAINT test__transactions__2025_04_generic_period_excl EXCLUDE USING gist (period WITH OPERATOR(&&))
)
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
