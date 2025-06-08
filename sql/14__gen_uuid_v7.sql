/*
    Generate a uuidv7 value with a 48-bits timestamp (milliseconds precision)
    and 74-bits of randomness.
*/
CREATE OR REPLACE FUNCTION pgpartium.gen_uuid_v7 (
    p_timestamptz timestamptz = pg_catalog.clock_timestamp()
)
RETURNS uuid
LANGUAGE SQL
VOLATILE
PARALLEL SAFE
SET search_path = pg_catalog
AS $BODY$
    -- Replace the first 48 bits of a uuidv4 with the current
    -- number of milliseconds since 1970-01-01 UTC
    -- and set the "version" field to 7 by flipping the 2 and 1 bit.
    SELECT CAST(
        encode(
            set_bit(
                set_bit(
                    overlay(
                        uuid_send(gen_random_uuid())
                        placing substring(int8send(CAST(EXTRACT(EPOCH FROM p_timestamptz) * 1000 AS bigint)) FROM 3) FROM 1 FOR 6
                    )
                  , 52
                  , 1
                )
              , 53
              , 1
            )
            , 'hex'
        )
        AS uuid
    );
$BODY$;
