# NeuralSQL
A neural network framework based on SQL engine is provided.
Actual on 30 sep 2022.

Main goal is open design, flexibility as much as possible, and easy automated integration within other projects.
Its dynamic allows:
- per-table activation function definition. So you an use, for ex, both sigma and hyperbolic tangens in the same project.
- 'live' behavior that allows cell creation / removing 'on the fly'.
  It makes possible to see how a net is getting elder with neural cell deaths.
- A SQL platform makes easier to use information located in 'big data' storages.

This SW is provided mainly for testing, scientific investigations, getting some experience and statistic about the approach.

High performance issues are not persued here. If one wants to improve it, for example, reducing dynamic SQL code, it can be dicussed as seaprate commerce project.
Any security and transaction design issues are not taked into account as well. This is a concept code mostly.

Code is written on Postgres plpgsql language. Portation to other platforms can be discussed as well.

I. The model description.
Network is made on some tables with following mandatory features:
1. Any table has a UNIQUE (coded as PRIMARY KEY) text column with fixed name 'ids' for cells' identification.
   The neurons are represented as rows in the table with its IDs in "ids" column.
2. Special real valued, NOT NULL, column for output sinapse named 'output'. It has to posess avtual signal value by the start of a step calculation.
3. Real valued columns named literally as IDs said in clause 1 above.
   They represents incoming signal weights form the sinapse output (from cell that is named as column name) to current cell.
   Null value means that the sinapse not connected to the current one and definetly will not be conected (hint to optimisators, teacher e.t.c.).
4. Other parameters are possible within other columns as the model extentions.
5. The model is launched in a dedicated scheme like 'sand box'.
   It use hardcoded table names hoping that they will be not conflicting with existing objects in a database.
6. Signal propagation is on 'cell-by-cell' basis. It means that incoming cell's signals are stable within cycle.
   It suppose that in cell chains sgnal wil propagate by steps, not immideately as done in classic.
   - The task of 'similtaneous propagation' can be passed using chains of the same length adding 'dummy transmitters' as needed.
   - It makes come grounding to the fact that in biosysmes signal propagation takes time ae well.
   - It makes possible to investigate cyclic cell bindings, where an A-cell is connected to a B-cell, and the B-cell is connected to the A-cell at the same time.
   - It supports dynamic data patterns
   - It is possible to get calculation on cell subset using WHERE clause in UPDATE statement.

Example table:
 ids  out   c1   c2   c3   c4   c5   c6   c7   c8
'c1'  1.0  null null null null null null null null
'c2'  1.0  null null null null null null null null
'c3'  1.0  null null null null null null null null
'c4'  1.0   0.4  0.8 null null null null null null
'c5'  1.0  null  0.4  0.6 null null null null null
'c6'  1.0  null null null  0.1  0.2 null null null
'c7'  1.0  null null null  0.5  0.9 null null null
'c8'  1.0  null null null null null  0.5  0.4 null

Represents:
c1-c3 input signals, c4-c8 - nural network, where c8 is output.

c1->\
     c4=>-->c6>
    /    \ /   \
c2>+      X     c8=>
    \    / \   /
     c5=>-->c7>
c3->/

One can see there that the matrix is made of 'blocks' with nulls otherwise.
Better processing of that cases in large cells projects is with using several-tables modelling approach because a table processing time is O(n^2).
