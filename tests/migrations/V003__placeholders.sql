DO $$
BEGIN
    IF '${region}' = 'fra' AND '${environment}' = 'dev' THEN
        RETURN;
    END IF;
END $$;
