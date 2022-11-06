psql --port=5432 --username=postgres --echo-errors -olog --file=install.psql -vdb_name=dbn -vpath=%cd%/ -vschema=sch00
