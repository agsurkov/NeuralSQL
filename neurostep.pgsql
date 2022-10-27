--
-- PostgreSQL neuro step functions to be implemented
-- sigma, tanh (hyperbolic tangens), echo.
--

-- State on 2022-09-29, by A. Surkov

--
-- ---------------------------------------------
--              STEP FUNCTIONS
-- ---------------------------------------------
--
-- neuro_calc(schema TEXT, wrk_tbl TEXT, cur_rec_id TEXT) RETURNS REAL
--
--  ---------- PARAMETERS -----------------
-- schema AS the schema.
-- wrk_tbl AS the name of the table being processed.
-- cur_rec_id AS the cell identificator under processing.
--
-- The funcion performs neuron cell propagation calculation step with given in the raw weights and existing in the table outputs of others cells.

CREATE FUNCTION :schema.neuro_calc(schema TEXT, wrk_tbl TEXT, cur_rec_id TEXT) RETURNS REAL
   LANGUAGE plpgsql
   AS $$

DECLARE 
  af INTEGER;
   r REAL;
  r0 REAL;
  r1 REAL;
 idx TEXT;
  tt TEXT;

BEGIN

r = 0.0;

EXECUTE format('SELECT ac_func FROM %I.%I WHERE ids = %L;', schema, wrk_tbl, cur_rec_id) INTO af;
IF af = 5 THEN RETURN NULL; END IF;

tt = format('SELECT ids FROM %I.%I;', schema, wrk_tbl);
FOR idx IN EXECUTE tt LOOP

-- weight
  EXECUTE format('SELECT %I     FROM %I.%I WHERE ids = %L;', idx, schema, wrk_tbl, cur_rec_id) INTO r0;
  CONTINUE WHEN r0 IS NULL;

-- output (output is defined as NOT NULL)
  EXECUTE format('SELECT output FROM %I.%I WHERE ids = %L;', schema, wrk_tbl, idx) INTO r1;
  
  r = r + r0 * r1;

END LOOP;

CASE af
  WHEN 1 THEN r = 1.0 / (1.0 + exp(-r));
  WHEN 2 THEN r = 2.0 / (1.0 + exp(-2.0 * r)) - 1.0;
  WHEN 3 THEN r = r;
  WHEN 4 THEN r = 0.0;   -- died cell: don't react to any signal
  ELSE        r = NULL;
END CASE;

RETURN r;
END;
$$;
--
--
--
CREATE PROCEDURE :schema.neuro_step(schema TEXT)
    LANGUAGE plpgsql
    AS $$

DECLARE 
  srct TEXT;  -- source table
  srcc TEXT;  -- source values
  dstt TEXT;  -- dest table
  dstc TEXT;  -- dest values
     r REAL;
    af INTEGER; -- ativation function code

BEGIN  
-- place incoming signals receiving code here.

-- ...

-- intratable signal propagation
FOR dstt, dstc IN EXECUTE format('SELECT dst_tbl, dst_col FROM %I.link_table', schema) LOOP
   EXECUTE format('SELECT src_tbl, src_col FROM %I.link_table;', schema) INTO srct, srcc;
   EXECUTE format('SELECT output FROM %I.%I WHERE ids = %L;', schema, srct, srcc) INTO r;
   EXECUTE format('UPDATE %I.%I SET output_tmp=%s WHERE ids=%L;', schema, dstt, CAST(r AS TEXT), srct || srcc);  -- change pseudocell's output value. TODO: investigate foreighn key usage to update
END LOOP;

-- TABLE PROCESSING
FOR dstt IN EXECUTE format('SELECT tbl FROM %I.config_table', schema) LOOP
   EXECUTE format('UPDATE %I.%I SET output_tmp = %I.neuro_calc(%L, %L, ids) WHERE ac_func <> 5;', schema, dstt, schema, schema, dstt);
   EXECUTE format('UPDATE %I.%I SET output = output_tmp;', schema, dstt);
END LOOP;

END;
$$;
--
-- Recording results into outpot gadgets defined in 
--
CREATE PROCEDURE :schema.neuro_stepout(schema TEXT)
    LANGUAGE plpgsql
    AS $$

DECLARE
seqno BIGINT;
  tmp TEXT;
  ttt TEXT;
 tbld TEXT;
 cold TEXT;
 tbls TEXT;
 cols TEXT;
    w REAL;

BEGIN
  EXECUTE 'SELECT curval(%I.neuro_epoch);' USING schema INTO seqno;

  tmp = format('SELECT DISTINCT dst_tbl FROM %I.res_def_table;', schema);
  FOR tbld IN EXECUTE tmp LOOP
    ttt = format('INSERT INTO %I.%I VALUES();', schema, tbld);    
    EXECUTE ttt;
  END LOOP;

  tmp = format('SELECT dst_tbl, dst_col, src_tbl, src_col, weight FROM %I.res_def_table;', schema);
  FOR tbld, cold, tbls, cols, w IN EXECUTE tmp LOOP
    ttt = format('UPDATE %I.%I FROM %I.%I SET %I = %I * %s);', schema, tbld, schema, cold, dst_col, src_col, w);
    RAISE NOTICE 'Resulting %', ttt;
    EXECUTE ttt;
  END LOOP;

END;
$$;
--
--
--
CREATE PROCEDURE :schema.neuro_steps(steps integer, schema TEXT)
    LANGUAGE plpgsql
    AS $$

BEGIN
  RAISE NOTICE 'STEPS % TO PERFORM', steps;
  IF steps < 0 THEN RAISE EXCEPTION 'NEGATIVE STEPS NUMBER TO PERFORM'; END IF;

  EXECUTE format('SELECT setval(%I.%L, 1);', schema, 'neuro_epoch');
  
  WHILE steps > 0 LOOP
    EXECUTE format('CALL %I.neuro_step(%L);', schema, schema);
    EXECUTE format('CALL %I.neuro_stepout(%L);', schema, schema);
    EXECUTE format('SELECT nextval(%I.%L);', schema, 'neuro_epoch');
    steps = steps - 1;
  END LOOP;

END;
$$;
