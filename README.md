Neuro net on sql.
The idea is copyrighted by A. Surkov, 2022.
The author's name has to be mentioned if the idea is implemented.

A neuro net support is based on SQL engine.
Main goal is open design and easy automated integration within other projects, not a high performance.

Code is written on Postgres plpgsql language.

I. The model description.
Network is created within single table with following mandatory features:
1. The table has a UNIQUE (coded as PRIMARY KEY) text column for neuron identification.
   The neurons are represented as rows in the table.
   Null value disables the record for future processing.
2. Special real valued not Null column for output sinapse, that is valued actual to begin of calculation.
3. Real valued columns named identically as values in clause 1.
   They represents incoming signal weights form sinapse named as column name to current one.
   Null value means that the sinapse not connected to current and definetly will not be conected.
4. Other parameters are possible within other columns as the model extentions.

Example table:
name  out   c1   c2   c3   c4   c5   c6   c7   c8

'c1'  1.0  null null null null null null null null

'c2'  1.0  null null null null null null null null

'c3'  1.0  null null null null null null null null

'c4'  1.0   0.4  0.8 null null null null null null

'c5'  1.0  null  0.4  0.6 null null null null null

'c6'  1.0  null null null  0.1  0.2 null null null

'c7'  1.0  null null null  0.5  0.9 null null null

'c8'  1.0  null null null null null  0.5  0.4 null


Represents:
c1-c3 input signals, c8 - output.

c1->\

     c4=>-->c6>

     /    \ /   \

c2>+       X     c8=>

    \    / \   /

    c5=>-->c7>

c3->/

The model supports self-connected cells, cycled connections.

II. Table creation by neurocreatetable() procedure.
    It is defined as neurocreatetable(table_name text, items_number integer, col_id_name text, out_id_name text, col_prefix text).
    All parameters are input, and have following meaning:
    - table_name  defines the name of the table to be created;
    - items_number defines number of sells to be created;
    - col_id_name defines the column's name that is described in I.1.
    - out_id_name defines the column's name that is described in I.2.
    - col_prefix defines prefix for cells naming. 
      Naming is performed as '<prefix value><seq number items_number ..1>'.
      Weights (columns values) are random 0..1 values.
	  The index '<col_id_name>_idx' is created as well.
    For example:
    CALL neurocreatetable('test', 2, 'id', 'out', 'c');
    This call produces a table named 'test' as follows:
 id   out   c1  c2
'c1'  0.0  0.3 0.5
'c2'  0.0  0.2 0.9

III. Step calculation by neurostep() function.
    It is defined as 'neurostep(table_name text, out_col_name text, ids_col_name text, cur_rec_id text) returns real'.
	All parameters are input, and have following meaning:
    - table_name  defines the name of the table to be created;
    - out_col_name defines the column's name where the input signal's value is collected.
    - ids_col_name defines the column's name where columns' identification are provided.
	- cur_rec_id defines the cell's id to be calculated by the function invocation.

    Note:
    For iterated calculations one should create temporary column. 
    Direct usage of ids_col_name column will cause a 'race condition' effect during calculations.

    Typical usage for a single epoch calculation:

    UPDATE tbl SET tmp = neurostep('tbl', 'out', 'id', id);
    UPDATE tbl SET out = tmp;
    
    The temporary column is used to get cell outputs stable during calculation.

    Notes:
    1. The results can be stored in another table.
    2. It is possible to get calculation on cell subset using WHERE clause in UPDATE statement.
