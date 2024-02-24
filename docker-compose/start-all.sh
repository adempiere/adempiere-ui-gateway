#!/bin/bash

# Script to -if necessary- create on host persistent directories and start the docker compose services

# Directory needed for storing persistently Postgres database on host.
# Directory will be created on host only if inexistent.
# Docker Compose will create this directory via volume definition.
DBDIR=postgresql/postgres_database
if [ ! -d "$DBDIR" ]; then
    echo "Directory \"$DBDIR\" does not exist. It must be created."
    echo "Create directory \"$DBDIR\""
    mkdir $DBDIR
else
    echo "Directory \"$DBDIR\" exists already: no need to create it"
fi

# Backup directory for storing the Postgres backup file on host.
# Directory will be created on host only if inexistent.
# Docker Compose will create this directory via volume definition.
# The name of the backup file must be "seed.backup" as defined in Docker Compose.
BACKUPDIR=postgresql/postgres_backups
if [ ! -d "$BACKUPDIR" ]; then
    echo "Directory \"$BACKUPDIR\" does not exist. It must be created."
    echo "Create directory \"$BACKUPDIR\""
    mkdir $BACKUPDIR
    chmod 777 $BACKUPDIR
else
    echo "Directory \"$BACKUPDIR\" exists already: no need to create it"
fi

# Directory needed for storing persistently ZK container files on host.
# Directory will be created only if inexistent.
# Docker Compose will create this directory via volume definition.
PERSISTENTDIR=postgresql/persistent_files
if [ ! -d "$PERSISTENTDIR" ]; then
    echo "Directory \"$PERSISTENTDIR\" does not exist. It must be created."
    echo "Create directory \"$PERSISTENTDIR\""
    mkdir $PERSISTENTDIR
    chmod 777 $PERSISTENTDIR
else
    echo "Directory \"$PERSISTENTDIR\" exists already: no need to create it"
fi

# Find out which Docker Compose file will be used.
# The script must be called with the flag "-d" + one of the following parameters [auth, cache, develop, storage, vue, default]
# e.g.: ./start-all.sh -d vue
# If script is called without or with a wrong flag, 'default' will be taken.
# e.g.: ./start-all.sh
while getopts d: flag
do
    case "${flag}" in
        d) docker_compose_option=${OPTARG};;
        *) docker_compose_option=default;;
    esac
done
echo "Script called with parameter: \"$docker_compose_option\"";
    
case "${docker_compose_option}" in
    auth)    docker_compose_file=docker-compose-auth.yml;;
    cache)   docker_compose_file=docker-compose-cache.yml;;
    develop) docker_compose_file=docker-compose-develop.yml;;
    storage) docker_compose_file=docker-compose-storage.yml;;
    vue)     docker_compose_file=docker-compose-vue.yml;;
    default) docker_compose_file=docker-compose.yml;;
    *)       docker_compose_file=docker-compose.yml;;
esac

# Save Docker Compose file name in file .DOCKER_COMPOSE_FILE
# This will be used in scripts stop-all.sh and stop-and-delete.all.sh to stop the started services.
savefile=.DOCKER_COMPOSE_FILE
echo $docker_compose_file > $savefile


echo "Docker Compose will be executed with file: \"$docker_compose_file\"";
cp env_template .env
docker compose -f $docker_compose_file up -d
