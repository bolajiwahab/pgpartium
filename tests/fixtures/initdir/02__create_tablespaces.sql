SELECT format($SQL$
    CREATE TABLESPACE %1$I
      LOCATION '/var/lib/pgpartix/tablespaces/%1$I';
$SQL$, 'pgpartix')
 WHERE NOT EXISTS (
    SELECT NULL
      FROM pg_catalog.pg_tablespace
     WHERE spcname = 'pgpartix')\gexec

SELECT format($SQL$
    CREATE TABLESPACE %1$I
      LOCATION '/var/lib/pgpartix/tablespaces/%1$I';
$SQL$, 'pgpartix_fast')
 WHERE NOT EXISTS (
    SELECT NULL
      FROM pg_catalog.pg_tablespace
     WHERE spcname = 'pgpartix_fast')\gexec
