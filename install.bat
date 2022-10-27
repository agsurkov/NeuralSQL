rem
"C:\Program Files\PostgreSQL\13\bin"\psql --port=5432 --username=postgres --echo-errors --file=install.psql -vdb_name=dbn -vpath=%cd%/ -vschema=sch0
