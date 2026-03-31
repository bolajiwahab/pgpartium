DO $$
BEGIN
    IF '${region}' = 'europe' AND '${environment}' = 'development' THEN
        INSERT INTO "schema" (name, created_at, updated_at) VALUES ('public', NOW(), NOW());
    END IF;
END $$;
