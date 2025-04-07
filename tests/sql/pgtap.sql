-- Sourced from https://github.com/theory/pgtap/blob/main/sql/pgtap.sql.in

CREATE SCHEMA IF NOT EXISTS pgtap;

SET search_path = 'pgtap';

CREATE OR REPLACE FUNCTION _get ( text )
RETURNS integer
LANGUAGE plpgsql strict
AS $$
DECLARE
    ret integer;
BEGIN
    EXECUTE 'SELECT value FROM __tcache__ WHERE label = ' || quote_literal($1) || ' LIMIT 1' INTO ret;
    RETURN ret;
END;
$$;


CREATE OR REPLACE FUNCTION num_failed ()
RETURNS INTEGER AS $$
    SELECT _get('failed');
$$ LANGUAGE SQL strict;


CREATE OR REPLACE FUNCTION _add ( text, integer, text )
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'INSERT INTO __tcache__ (label, value, note) values (' ||
    quote_literal($1) || ', ' || $2 || ', ' || quote_literal(COALESCE($3, '')) || ')';
    RETURN $2;
END;
$$;


CREATE OR REPLACE FUNCTION _set ( text, integer, text )
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    rcount integer;
BEGIN
    EXECUTE 'UPDATE __tcache__ SET value = ' || $2
        || CASE WHEN $3 IS NULL THEN '' ELSE ', note = ' || quote_literal($3) END
        || ' WHERE label = ' || quote_literal($1);
    GET DIAGNOSTICS rcount = ROW_COUNT;
    IF rcount = 0 THEN
       RETURN _add( $1, $2, $3 );
    END IF;
    RETURN $2;
END;
$$;


CREATE OR REPLACE FUNCTION _set ( text, integer )
RETURNS integer
LANGUAGE SQL
AS $$
    SELECT _set($1, $2, '')
$$;


CREATE OR REPLACE FUNCTION _error_diag( TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT )
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT COALESCE(
               COALESCE( NULLIF($1, '') || ': ', '' ) || COALESCE( NULLIF($2, ''), '' ),
               'NO ERROR FOUND'
           )
        || COALESCE(E'\n        DETAIL:     ' || nullif($3, ''), '')
        || COALESCE(E'\n        HINT:       ' || nullif($4, ''), '')
        || COALESCE(E'\n        SCHEMA:     ' || nullif($6, ''), '')
        || COALESCE(E'\n        TABLE:      ' || nullif($7, ''), '')
        || COALESCE(E'\n        COLUMN:     ' || nullif($8, ''), '')
        || COALESCE(E'\n        CONSTRAINT: ' || nullif($9, ''), '')
        || COALESCE(E'\n        TYPE:       ' || nullif($10, ''), '')
        -- We need to manually indent all the context lines
        || COALESCE(E'\n        CONTEXT:\n'
               || regexp_replace(NULLIF( $5, ''), '^', '            ', 'gn'
           ), '');
$$;


CREATE OR REPLACE FUNCTION diag ( msg text )
RETURNS TEXT
LANGUAGE sql strict
AS $$
    SELECT '# ' || replace(
       replace(
            replace( $1, E'\r\n', E'\n# ' ),
            E'\n',
            E'\n# '
        ),
        E'\r',
        E'\n# '
    );
$$;


CREATE OR REPLACE FUNCTION plan( integer )
RETURNS TEXT
LANGUAGE plpgsql strict
AS $$
DECLARE
    rcount INTEGER;
BEGIN
    BEGIN
        EXECUTE '
            CREATE TEMP SEQUENCE __tcache___id_seq;
            CREATE TEMP TABLE __tcache__ (
                id    INTEGER NOT NULL DEFAULT nextval(''__tcache___id_seq''),
                label TEXT    NOT NULL,
                value INTEGER NOT NULL,
                note  TEXT    NOT NULL DEFAULT ''''
            );
            CREATE UNIQUE INDEX __tcache___key ON __tcache__(id);
            GRANT ALL ON TABLE __tcache__ TO PUBLIC;
            GRANT ALL ON TABLE __tcache___id_seq TO PUBLIC;

            CREATE TEMP SEQUENCE __tresults___numb_seq;
            GRANT ALL ON TABLE __tresults___numb_seq TO PUBLIC;
        ';

    EXCEPTION WHEN duplicate_table THEN
        -- Raise an exception if there's already a plan.
        EXECUTE 'SELECT TRUE FROM __tcache__ WHERE label = ''plan''';
      GET DIAGNOSTICS rcount = ROW_COUNT;
        IF rcount > 0 THEN
           RAISE EXCEPTION 'You tried to plan twice!';
        END IF;
    END;

    -- Save the plan and return.
    PERFORM _set('plan', $1 );
    PERFORM _set('failed', 0 );
    RETURN '1..' || $1;
END;
$$;


CREATE OR REPLACE FUNCTION _finish (INTEGER, INTEGER, INTEGER, BOOLEAN DEFAULT NULL)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    curr_test ALIAS FOR $1;
    exp_tests INTEGER := $2;
    num_faild ALIAS FOR $3;
    plural    CHAR;
    raise_ex  ALIAS FOR $4;
BEGIN
    plural    := CASE exp_tests WHEN 1 THEN '' ELSE 's' END;

    IF curr_test IS NULL THEN
        RAISE EXCEPTION '# No tests run!';
    END IF;

    IF exp_tests = 0 OR exp_tests IS NULL THEN
         -- No plan. Output one now.
        exp_tests = curr_test;
        RETURN NEXT '1..' || exp_tests;
    END IF;

    IF curr_test <> exp_tests THEN
        RETURN NEXT diag(
            'Looks like you planned ' || exp_tests || ' test' ||
            plural || ' but ran ' || curr_test
        );
    ELSIF num_faild > 0 THEN
        IF raise_ex THEN
            RAISE EXCEPTION  '% test% failed of %', num_faild, CASE num_faild WHEN 1 THEN '' ELSE 's' END, exp_tests;
        END IF;
        RETURN NEXT diag(
            'Looks like you failed ' || num_faild || ' test' ||
            CASE num_faild WHEN 1 THEN '' ELSE 's' END
            || ' of ' || exp_tests
        );
    ELSE

    END IF;
    RETURN;
END;
$$;


CREATE OR REPLACE FUNCTION finish (exception_on_failure BOOLEAN DEFAULT NULL)
RETURNS SETOF TEXT
LANGUAGE sql
AS $$
    SELECT * FROM _finish(
        _get('curr_test'),
        _get('plan'),
        num_failed(),
        $1
    );
$$;


CREATE OR REPLACE FUNCTION _query( TEXT )
RETURNS TEXT
LANGUAGE SQL
AS $$
    SELECT CASE
        WHEN $1 LIKE '"%' OR $1 !~ '[[:space:]]' THEN 'EXECUTE ' || $1
        ELSE $1
    END;
$$;


CREATE OR REPLACE FUNCTION _get_latest ( text )
RETURNS integer[]
LANGUAGE plpgsql strict
AS $$
DECLARE
    ret integer[];
BEGIN
    EXECUTE 'SELECT ARRAY[id, value] FROM __tcache__ WHERE label = ' ||
    quote_literal($1) || ' AND id = (SELECT MAX(id) FROM __tcache__ WHERE label = ' ||
    quote_literal($1) || ') LIMIT 1' INTO ret;
    RETURN ret;
EXCEPTION WHEN undefined_table THEN
   RAISE EXCEPTION 'You tried to run a test without a plan! Gotta have a plan';
END;
$$;


CREATE OR REPLACE FUNCTION _todo()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    todos INT[];
    note text;
BEGIN
    -- Get the latest id and value, because todo() might have been called
    -- again before the todos ran out for the first call to todo(). This
    -- allows them to nest.
    todos := _get_latest('todo');
    IF todos IS NULL THEN
        -- No todos.
        RETURN NULL;
    END IF;
    IF todos[2] = 0 THEN
        -- Todos depleted. Clean up.
        EXECUTE 'DELETE FROM __tcache__ WHERE id = ' || todos[1];
        RETURN NULL;
    END IF;
    -- Decrement the count of counted todos and return the reason.
    IF todos[2] <> -1 THEN
        PERFORM _set(todos[1], todos[2] - 1);
    END IF;
    note := _get_note(todos[1]);

    IF todos[2] = 1 THEN
        -- This was the last todo, so delete the record.
        EXECUTE 'DELETE FROM __tcache__ WHERE id = ' || todos[1];
    END IF;

    RETURN note;
END;
$$;


CREATE OR REPLACE FUNCTION add_result ( bool, bool, text, text, text )
RETURNS integer
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT $1 THEN PERFORM _set('failed', _get('failed') + 1); END IF;
    RETURN nextval('__tresults___numb_seq');
END;
$$;


CREATE OR REPLACE FUNCTION ok ( boolean, text )
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
   aok      ALIAS FOR $1;
   descr    text := $2;
   test_num INTEGER;
   todo_why TEXT;
   ok       BOOL;
BEGIN
   todo_why := _todo();
   ok       := CASE
       WHEN aok = TRUE THEN aok
       WHEN todo_why IS NULL THEN COALESCE(aok, false)
       ELSE TRUE
    END;
    IF _get('plan') IS NULL THEN
        RAISE EXCEPTION 'You tried to run a test without a plan! Gotta have a plan';
    END IF;

    test_num := add_result(
        ok,
        COALESCE(aok, false),
        descr,
        CASE WHEN todo_why IS NULL THEN '' ELSE 'todo' END,
        COALESCE(todo_why, '')
    );

    RETURN (CASE aok WHEN TRUE THEN '' ELSE 'not ' END)
           || 'ok ' || _set( 'curr_test', test_num )
           || CASE descr WHEN '' THEN '' ELSE COALESCE( ' - ' || substr(diag( descr ), 3), '' ) END
           || COALESCE( ' ' || diag( 'TODO ' || todo_why ), '')
           || CASE aok WHEN TRUE THEN '' ELSE E'\n' ||
                diag('Failed ' ||
                CASE WHEN todo_why IS NULL THEN '' ELSE '(TODO) ' END ||
                'test ' || test_num ||
                CASE descr WHEN '' THEN '' ELSE COALESCE(': "' || descr || '"', '') END ) ||
                CASE WHEN aok IS NULL THEN E'\n' || diag('    (test result was NULL)') ELSE '' END
           END;
END;
$$;


-- throws_ok ( sql, errcode, errmsg, description )
CREATE OR REPLACE FUNCTION throws_ok ( TEXT, CHAR(5), TEXT, TEXT )
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    query     TEXT := _query($1);
    errcode   ALIAS FOR $2;
    errmsg    ALIAS FOR $3;
    desctext  ALIAS FOR $4;
    descr     TEXT;
BEGIN
    descr := COALESCE(
          desctext,
          'threw ' || errcode || ': ' || errmsg,
          'threw ' || errcode,
          'threw ' || errmsg,
          'threw an exception'
    );
    EXECUTE query;
    RETURN ok( FALSE, descr ) || E'\n' || diag(
           '      caught: no exception' ||
        E'\n      wanted: ' || COALESCE( errcode, 'an exception' )
    );
EXCEPTION WHEN OTHERS OR ASSERT_FAILURE THEN
    IF (errcode IS NULL OR SQLSTATE = errcode)
        AND ( errmsg IS NULL OR SQLERRM = errmsg)
    THEN
        -- The expected errcode and/or message was thrown.
        RETURN ok( TRUE, descr );
    ELSE
        -- This was not the expected errcode or errmsg.
        RETURN ok( FALSE, descr ) || E'\n' || diag(
               '      caught: ' || SQLSTATE || ': ' || SQLERRM ||
            E'\n      wanted: ' || COALESCE( errcode, 'an exception' ) ||
            COALESCE( ': ' || errmsg, '')
        );
    END IF;
END;
$$;


-- lives_ok( sql, description )
CREATE OR REPLACE FUNCTION lives_ok ( TEXT, TEXT )
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    code  TEXT := _query($1);
    descr ALIAS FOR $2;
    detail  text;
    hint    text;
    context text;
    schname text;
    tabname text;
    colname text;
    chkname text;
    typname text;
BEGIN
    EXECUTE code;
    RETURN ok( TRUE, descr );
EXCEPTION WHEN OTHERS OR ASSERT_FAILURE THEN
    -- There should have been no exception.
    GET STACKED DIAGNOSTICS
        detail  = PG_EXCEPTION_DETAIL,
        hint    = PG_EXCEPTION_HINT,
        context = PG_EXCEPTION_CONTEXT,
        schname = SCHEMA_NAME,
        tabname = TABLE_NAME,
        colname = COLUMN_NAME,
        chkname = CONSTRAINT_NAME,
        typname = PG_DATATYPE_NAME;
    RETURN ok( FALSE, descr ) || E'\n' || diag(
           '    died: ' || _error_diag(SQLSTATE, SQLERRM, detail, hint, context, schname, tabname, colname, chkname, typname)
    );
END;
$$;


-- performs_ok ( sql, milliseconds, description )
CREATE OR REPLACE FUNCTION performs_ok ( TEXT, NUMERIC, TEXT )
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    query     TEXT := _query($1);
    max_time  ALIAS FOR $2;
    descr     ALIAS FOR $3;
    starts_at TEXT;
    act_time  NUMERIC;
BEGIN
    starts_at := timeofday();
    EXECUTE query;
    act_time := extract( millisecond from timeofday()::timestamptz - starts_at::timestamptz);
    IF act_time < max_time THEN RETURN ok(TRUE, descr); END IF;
    RETURN ok( FALSE, descr ) || E'\n' || diag(
           '      runtime: ' || act_time || ' ms' ||
        E'\n      exceeds: ' || max_time || ' ms'
    );
END;
$$;


-- performs_within( sql, average_milliseconds, within, iterations, description )
CREATE TYPE _time_trial_type
AS (a_time NUMERIC);

CREATE OR REPLACE FUNCTION _time_trials(TEXT, INT, NUMERIC)
RETURNS SETOF _time_trial_type
LANGUAGE plpgsql
AS $$
DECLARE
    query            TEXT := _query($1);
    iterations       ALIAS FOR $2;
    return_percent   ALIAS FOR $3;
    start_time       TEXT;
    act_time         NUMERIC;
    times            NUMERIC[];
    offset_it        INT;
    limit_it         INT;
    offset_percent   NUMERIC;
    a_time           _time_trial_type;
BEGIN
    -- Execute the query over and over
    FOR i IN 1..iterations LOOP
        start_time := timeofday();
        EXECUTE query;
        -- Store the execution time for the run in an array of times
        times[i] := extract(millisecond from timeofday()::timestamptz - start_time::timestamptz);
    END LOOP;
    offset_percent := (1.0 - return_percent) / 2.0;
    -- Ensure that offset skips the bottom X% of runs, or set it to 0
    SELECT GREATEST((offset_percent * iterations)::int, 0) INTO offset_it;
    -- Ensure that with limit the query to returning only the middle X% of runs
    SELECT GREATEST((return_percent * iterations)::int, 1) INTO limit_it;

    FOR a_time IN SELECT times[i]
        FROM generate_series(array_lower(times, 1), array_upper(times, 1)) i
                  ORDER BY 1
                  OFFSET offset_it
                  LIMIT limit_it LOOP
    RETURN NEXT a_time;
    END LOOP;
END;
$$;


CREATE OR REPLACE FUNCTION performs_within(TEXT, NUMERIC, NUMERIC, INT, TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    query          TEXT := _query($1);
    expected_avg   ALIAS FOR $2;
    within         ALIAS FOR $3;
    iterations     ALIAS FOR $4;
    descr          ALIAS FOR $5;
    avg_time       NUMERIC;
BEGIN
  SELECT avg(a_time) FROM _time_trials(query, iterations, 0.8) t1 INTO avg_time;
  IF abs(avg_time - expected_avg) < within THEN RETURN ok(TRUE, descr); END IF;
  RETURN ok(FALSE, descr) || E'\n' || diag(' average runtime: ' || avg_time || ' ms'
     || E'\n desired average: ' || expected_avg || ' +/- ' || within || ' ms'
    );
END;
$$;
