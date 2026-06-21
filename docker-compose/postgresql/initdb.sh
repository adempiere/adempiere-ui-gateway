#!/bin/bash

# This file will be automatically executed only when there is no database installed.
# If a database is detected, this file will be skipped, whatever the contents of the database are.

echo "Starting DB initialization."

echo "Check if user 'adempiere' exists."
if [ "$( psql -U $POSTGRES_USER -tAc "SELECT 1 FROM pg_roles WHERE rolname='adempiere'" )" != '1' ]; then
	echo "The role 'adempiere' does not exist -->> it will be created and restored"
	createuser -U postgres adempiere -dlrs
	psql -U postgres -tAc "ALTER USER adempiere password 'adempiere';"
fi

# Test database existence
echo "Check if database 'adempiere' exists."
if [[ -z `psql -Atqc '\list adempiere' postgres` ]]; then
	echo "The database 'adempiere' does not exist -->> it will be created and restored"
	echo "Restore of database 'adempiere' starting..."
	createdb -U adempiere adempiere

	echo "Check if a seed restore file exists ($POSTGRES_DEFAULT_RESTORE_FILE)"
	if [ -f "$POSTGRES_DEFAULT_RESTORE_FILE" ]; then
		echo "File $POSTGRES_DEFAULT_RESTORE_FILE exists -->> Proceed to restore DB using this file."
	else
		echo "File $POSTGRES_DEFAULT_RESTORE_FILE does not exist -->> Proceed to restore DB using ADempiere's seed."
		echo "I am the user: " `whoami`   # It should be "postgres"

		IS_PSQL=0
		if [ -d "$POSTGRES_DB_BACKUP_PATH_ON_CONTAINER" ]; then
			echo "Create directory ${POSTGRES_DB_BACKUP_PATH_ON_CONTAINER}"
			# mkdir -p $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER
			# chown -R `whoami`:`whoami` $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER
			IS_PSQL=1
		fi
		cd $POSTGRES_DB_BACKUP_PATH_ON_CONTAINER
		echo "I am on directory: " `pwd`   # It should be "postgres"

		# Create temp directory with proper permissions
		TEMP_EXTRACT_DIR=$(mktemp -d)
		chown postgres:postgres $TEMP_EXTRACT_DIR
		echo "Create temp directory with permissions $TEMP_EXTRACT_DIR"

		echo "Downloading ADempiere artifact from Github... It may take some time"
		echo "Download URL $ADEMPIERE_GITHUB_ARTIFACT"
		wget --no-check-certificate --content-disposition $ADEMPIERE_GITHUB_ARTIFACT -P $TEMP_EXTRACT_DIR
		echo "Result from ls -la: " `ls -la`

		echo "Check file $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE was downloaded"
		if [ -f "$TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE" ]; then
			echo "File $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE was downloaded"
			echo "Unpack $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE here... It may take some time"
			# With all artifact release generate
			tar -xvf $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE -C $TEMP_EXTRACT_DIR

			echo "Result from ls -la: " `ls -la`
			ls $TEMP_EXTRACT_DIR -la
			echo "Rename adempiere_ui_postgresql_seed.backup to $POSTGRES_RESTORE_FILE_NAME. Any existing file with same name will disappear!"
			mv $TEMP_EXTRACT_DIR/adempiere_ui_postgresql_seed.backup $POSTGRES_DEFAULT_RESTORE_FILE
			IS_PSQL=0

			echo "Result from ls -la: " `ls $TEMP_EXTRACT_DIR -la`

			echo "Delete $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE"
			rm -rf $TEMP_EXTRACT_DIR/$ADEMPIERE_GITHUB_COMPRESSED_FILE
			echo "Result from ls -la: " `ls -la`
		else
			echo "ERROR: File $ADEMPIERE_GITHUB_COMPRESSED_FILE could not be downloaded."
			echo "Process will be stopped."
			exit 1
		fi
	fi

	echo "Ready to start DB restore"
	echo "Restoring ADempiere artifact from Github... It may take some time"
	# The following command is not used anymore. Left because of legacy.
	if [ $IS_PSQL -eq 1 ]; then
		echo "Restore with 'psql'"
		psql -U adempiere -v -d adempiere < $POSTGRES_DEFAULT_RESTORE_FILE
	else
		echo "Restore with 'pg_restore'"
		pg_restore -U adempiere -v -d adempiere < $POSTGRES_DEFAULT_RESTORE_FILE  # In case Backup was created with pg_dump
	fi
	echo "Restore of database 'adempiere' finished"
	echo "Test that database 'adempiere' was created:"
	psql -Atqc '\list adempiere'
else
	echo "Database 'adempiere' does already exist -->> it needs not be created"
fi

AFTER_RUN_DIR="/tmp/after_run"
if [ -d "$AFTER_RUN_DIR" ]; then
	echo "Import all SQL files on ${AFTER_RUN_DIR}"
	find "$AFTER_RUN_DIR" -maxdepth 1 -type f -name '*.sql' -print0 | while IFS= read -r -d '' file; do
		echo "importing $file"
		psql -U postgres < "$file"
	done
fi
