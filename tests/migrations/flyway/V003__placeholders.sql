DO $$
BEGIN
    IF '${region}' = 'fra' AND '${environment}' = 'dev' THEN
        INSERT INTO "schema" (name, created_at, updated_at) VALUES ('public', NOW(), NOW());
    END IF;
END $$;
