SELECT format($SQL$
    CREATE TABLESPACE %1$I
      LOCATION '/var/lib/postgresql/tablespaces/%1$I';
$SQL$, 'pgpartium')
 WHERE NOT EXISTS (
    SELECT NULL
      FROM pg_catalog.pg_tablespace
     WHERE spcname = 'pgpartium')\gexec

SELECT format($SQL$
    CREATE TABLESPACE %1$I
      LOCATION '/var/lib/postgresql/tablespaces/%1$I';
$SQL$, 'pgpartium_fast')
 WHERE NOT EXISTS (
    SELECT NULL
      FROM pg_catalog.pg_tablespace
     WHERE spcname = 'pgpartium_fast')\gexec
