CREATE TABLE test.test__transactions__2025_04
    PARTITION OF test.transactions (
        CONSTRAINT test__transactions__2025_04_custom_pkey PRIMARY KEY (transaction_id)
      , CONSTRAINT test__transactions__2025_04_custom_user_id_unique UNIQUE (user_id)
      , CONSTRAINT test__transactions__2025_04_custom_account_id_foreign FOREIGN KEY (account_id) REFERENCES test.accounts (account_id)
      , CONSTRAINT test__transactions__2025_04_custom_amount_validation CHECK (amount > CAST(0 AS numeric))
      , CONSTRAINT test__transactions__2025_04_custom_period_exclusion EXCLUDE USING gist (period WITH OPERATOR(&&))
    )
    FOR VALUES FROM ('2025-04-01 00:00:00+00') TO ('2025-05-01 00:00:00+00');
