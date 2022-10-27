-- Neural SQL project
--
-- PostgreSQL table create procedures.
--
-- State on 2022-10-27 by A. Surkov.
--
--
--  ---------- PARAMETERS -----------------
-- schema AS the destination schema
--
-- The procedure will create working table (based on data existing in the 'config_table' table, imported from 'data.cft' backup file).
-- The procedure will also create an index named "<table_name>_tbl_idx" on ids column.
-- No access management action performed here leaving the matter to upper level of execution.
-- Neurons' records in the new table are created as well. They have:
-- -- ranodm(0..1) in output column, 
-- -- NULL value in neurons' weight columns (fully disjoint set), actual connections is expected to be set by user separately.

CREATE PROCEDURE :schema.neurocreatetables(schema TEXT)
    LANGUAGE plpgsql
    AS $$

DECLARE 
   sn INTEGER;
   af INTEGER;
   pf TEXT;
  idx TEXT;
  ttt TEXT;

BEGIN

  FOR idx IN EXECUTE format('SELECT tbl FROM %I.config_table;', schema) LOOP

    EXECUTE format('SELECT number, prefix, ac_func FROM %I.config_table WHERE tbl=%L;', schema , idx) INTO sn, pf, af;
    IF sn IS NULL OR pf IS NULL OR af IS NULL THEN RAISE EXCEPTION 'Invalid config parameter!'; END IF;
    IF sn < 0 THEN RAISE EXCEPTION 'Negative cells number!'; END IF;

    EXECUTE format(''
            'CREATE TABLE %I.%I ('
            '  ids TEXT NOT NULL PRIMARY KEY,'
            '  ac_func INTEGER NOT NULL DEFAULT %s,'
            '  output_tmp REAL,'
            '  output REAL NOT NULL DEFAULT random());',  schema, idx, CAST(af AS TEXT));

    WHILE sn > 0 LOOP
      ttt = format('%s%s', pf, CAST(sn AS TEXT));

      EXECUTE format('ALTER TABLE %I.%I ADD COLUMN %I REAL;', schema, idx, ttt);
      EXECUTE format('INSERT INTO %I.%I (ids)  VALUES (%L);', schema, idx, ttt);
      COMMIT;

      sn = sn - 1;
    END LOOP;

    EXECUTE format('CREATE UNIQUE INDEX %s_tbl_idx ON %I.%I (ids);', idx,  schema, idx);

  END LOOP;
  RAISE NOTICE 'Neural network working tables are created';
END;
$$;
--
--
CREATE OR REPLACE PROCEDURE :schema.neurocreatetablelinks(schema TEXT)
    LANGUAGE plpgsql
    AS $$

DECLARE 
  idxt TEXT; -- dest table
  idxu TEXT;
  idxs TEXT;
  tmpt TEXT;
  coln TEXT;
    sn TEXT;  -- src cell's name
    st TEXT;  -- src table
     w REAL; 
     i INTEGER; 

BEGIN
  tmpt = format('SELECT dst_tbl, src_tbl, dst_col, src_col, weight FROM %I.link_table;', schema); 
  FOR idxt, st, idxs, sn, w IN EXECUTE tmpt LOOP                                                         -- CONSTRAINT UNIQUE(...) on link_table guaranties that only one row will be found.

    coln = st || sn;                                                                                     -- new column in dest table is named as <reference table name> || <ref col name>

    IF w IS NULL THEN        -- remove current relation
      i = 0;
      EXECUTE format('UPDATE %I.%I SET %I = NULL WHERE ids = %L;', schema, idxt, coln, idxs);            -- remove link setting it as NULL.
      EXECUTE format('SELECT count(%I) FROM %I.%I;', coln, schema, idxt) INTO i;                         -- count remainig links to given source whether to remove its representation if no links wes found
      COMMIT;
      IF i > 0 THEN CONTINUE; END IF;                                                                    -- links still exists - keep the record

      EXECUTE format('ALTER TABLE %I.%I DROP COLUMN %I;', schema, idxt, coln);                           -- No links - remove weigth column
      EXECUTE format('DELETE FROM %I.%I WHERE ids = %L;', schema, idxt, coln);                           -- and representing item as well
      COMMIT;
      CONTINUE;
    END IF;

    EXECUTE format('SELECT count(output) FROM %I.%I WHERE ids = %L;', schema, idxt, coln) INTO i;        -- check if we have to change existing item. If its id exists then column has to exist as well.
    IF i = 0 THEN                                                                                        -- If doesn't exict, we'll create it
      EXECUTE format('ALTER TABLE %I.%I ADD COLUMN %I REAL;', schema, idxt, coln);                       -- 
      EXECUTE format('INSERT INTO %I.%I (ids, ac_func)  VALUES (%L, 5);', schema, idxt, coln);           -- ac func of 5 is signal propagation, the record will not be processed by step engine.
      COMMIT;
    END IF;
 
    EXECUTE format('UPDATE      %I.%I SET %I=%s WHERE ids=%L;', schema, idxt, coln, w, idxs);            --
    COMMIT;
  END LOOP;
  
END;
$$;
--
--
CREATE OR REPLACE PROCEDURE :schema.neurocreateresulttable(schema TEXT)
    LANGUAGE plpgsql
    AS $$

DECLARE
     i INTEGER;
   tmp TEXT;
   ttt TEXT;
  tbls TEXT;
  cols TEXT;
  tbld TEXT;
  cold TEXT;

BEGIN

-- result tables framework
  tmp = format('SELECT DISTINCT dst_tbl FROM %I.res_def_table;', schema);
  FOR tbld IN EXECUTE tmp LOOP
    ttt = format('CREATE TABLE %I.%I (epoch BIGINT NOT NULL PRIMARY KEY DEFAULT currval(%L));', schema, tbld, schema || '.neuro_epoch');
    EXECUTE ttt;
    RAISE NOTICE 'Result table %.% created', schema, tbld;
  END LOOP;

-- result tables customization
  tmp = format('SELECT dst_tbl, dst_col FROM %I.res_def_table;', schema);
  FOR tbld, cold IN EXECUTE tmp LOOP
    ttt = format('ALTER TABLE %I.%I ADD COLUMN %I REAL;', schema, tbld, cold);
    EXECUTE ttt;
  END LOOP;
END;
$$;
