#!/bin/bash

if [ "$( psql -U $POSTGRES_USER -tAc "SELECT 1 FROM pg_roles WHERE rolname='adempiere'" )" != '1' ]
then
    createuser -U postgres adempiere -dlrs
    psql -U postgres -tAc "alter user adempiere password 'adempiere';"
    createdb -U adempiere adempiere
    psql -U adempiere -d adempiere < Adempiere_pg.dmp
fi

AFTER_RUN_DIR="/tmp/after_run"
for file in $AFTER_RUN_DIR/*.sql; do
    echo "importing $file"
    psql -U postgres < $file
done
