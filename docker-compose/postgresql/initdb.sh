#!/bin/bash

# This file is skipped automatically when in docker compose there is an image defined or the database is already installed in the container.

echo "Starting DB initialization."
echo "Check if database 'adempiere' exists."

#if [ "$( psql -U $POSTGRES_USER -tAc "SELECT 1 FROM pg_roles WHERE rolname='adempiere'" )" != '1' ]
#if [[ -z `psql -Atqc '\list adempiere' postgres` ]]  # Test database existence
#then
    echo "The database 'adempiere' does not exist -->> it will be created and restored"
    createuser -U postgres adempiere -dlrs
    psql -U postgres -tAc "alter user adempiere password 'adempiere';"
    createdb -U adempiere adempiere

    echo "Restore of database 'adempiere' starting..."
    echo "Check if a seed restore file exists ($POSTGRES_DEFAULT_RESTORE_FILE)"
 #   if [ -f "$POSTGRES_DEFAULT_RESTORE_FILE" ]
 #   then
 #     echo "File $POSTGRES_DEFAULT_RESTORE_FILE exists -->> Proceed to restore DB using this file."
 #   else
      echo "File $POSTGRES_DEFAULT_RESTORE_FILE does not exist -->> Proceed to restore DB using ADempiere's seed."
      echo "I am the user: " `whoami`   # It should be "postgres"
      echo "Download ADempiere artifact from Github."
      cd $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER
      echo "I am on directory: " `pwd`   # It should be "postgres"
      echo "Downloading ADempiere artifact from Github.... It may take some time"
      wget --no-check-certificate --content-disposition $ADEMPIERE_GITHUB_ARTIFACT
      echo "Result from ls -la: " `ls -la`
      echo "Unpack $ADEMPIERE_GITHUB_COMPRESSED_FILE here.... It may take some time"
      tar -xvf $ADEMPIERE_GITHUB_COMPRESSED_FILE Adempiere/data/Adempiere_pg.dmp  -C .
      echo "Result from ls -la: " `ls -la`
      echo "Rename Adempiere_pg.dmp to $POSTGRES_RESTORE_FILE_NAME. Any existing file with same name will disappear!"
      mv Adempiere/data/Adempiere_pg.dmp $POSTGRES_RESTORE_FILE_NAME
      echo "Result from ls -la: " `ls -la`
      rm -rf Adempiere
      echo "Delete $ADEMPIERE_GITHUB_COMPRESSED_FILE    "
      rm $ADEMPIERE_GITHUB_COMPRESSED_FILE
      echo "Result from ls -la: " `ls -la`
 #   fi

    # The following commands are not used anymore. Left because od legacy.
    #psql -U adempiere -d adempiere < Adempiere/data/Adempiere_pg.dmp
    #pg_restore -U adempiere -d adempiere < /tmp/seed.backup -v  # In case Backup was created with pg_dump
    echo "Ready to start DB restore"
    echo "Restoring  ADempiere artifact from Github.... It may take some time"
    psql -U adempiere -d adempiere < $POSTGRES_DEFAULT_RESTORE_FILE
    #psql -U adempiere -d adempiere < Adempiere_pg.dmp
    echo "Restore of database 'adempiere' finished"
    echo "Test that database 'adempiere' was created:"
    psql -Atqc '\list adempiere'
#else
#    echo "Database 'adempiere' does already exist -->> it needs not be created"
#fi

AFTER_RUN_DIR="/tmp/after_run"
for file in $AFTER_RUN_DIR/*; do
    echo "importing $file"
    psql -U postgres < $file
done
