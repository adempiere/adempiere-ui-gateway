#!/bin/bash

# Script to -if necessary-
#   1.- create on host persistent directories and
#   2.- start the docker compose services

# 1.- CREATE ON HOST PERSISTENT DIRECTORIES
#     Directory needed for storing persistently Postgres database on host.
#     Directory will be created on host only if inexistent.
#     Docker Compose will create this directory via volume definition.
DBDIR=postgresql/postgres_database
if [ ! -d "$DBDIR" ]; then
    echo "Directory \"$DBDIR\" does not exist. It must be created."
    echo "Create directory \"$DBDIR\""
	mkdir -p $DBDIR
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
	mkdir -p $BACKUPDIR
    chmod 777 $BACKUPDIR
else
    echo "Directory \"$BACKUPDIR\" exists already: no need to create it."
fi

# Directory needed for storing persistently ZK container files on host.
# Directory will be created only if inexistent.
# Docker Compose will create this directory via volume definition.
PERSISTENTDIR=postgresql/persistent_files
if [ ! -d "$PERSISTENTDIR" ]; then
    echo "Directory \"$PERSISTENTDIR\" does not exist. It must be created."
    echo "Create directory \"$PERSISTENTDIR\""
	mkdir -p $PERSISTENTDIR
    chmod 777 $PERSISTENTDIR
else
    echo "Directory \"$PERSISTENTDIR\" exists already: no need to create it."
fi

# Environment file to set values on docker compose file.
# Behavior:
# - If docker-compose/override.env exists -> generate merged .env using generate-env.sh
# - Else if .env does not exist -> copy env_template.env to .env
# - Else (.env exists and no override) -> keep existing .env (do not overwrite)
GENERATOR_SCRIPT="$(dirname "$0")/generate-env.sh"
if [ -f "$(dirname "$0")/override.env" ]; then
    echo "Found override.env -> generating .env via generate-env.sh"
    # call wrapper which runs the python generator
    "$GENERATOR_SCRIPT" "$(dirname "$0")/override.env" "$(dirname "$0")/.env"
elif [ ! -f .env ]; then
    echo "Creating .env from env_template.env"
    cp -f env_template.env .env
else
    echo ".env already exists and no override.env found — keeping existing .env"
fi


# 2 set profiles
PROFILES="all"
if [ -n "$1" ] && [[ "$1" != -* ]]; then
    PROFILES="$1"
fi
echo "Profiles: \"$PROFILES\""
export PROFILES


# # `--detach` / `-d` run Docker Compose services in the background
# # TODO: When it does not have the first argument of profiles that starts `all`, it takes `-d` (if it exists) as profile erroneously.
# DETACH=""
# if [ -n $2 ] && [ ! -z $2 ]; then
#     DETACH=$2
# fi
# export $DETACH




# 3.- Execute docker compose
DOCKER_COMPOSE_FILE=docker-compose.yml
echo "Docker Compose will be executed with file: \"$DOCKER_COMPOSE_FILE\""
#docker compose -f $DOCKER_COMPOSE_FILE --dry-run up -d
COMPOSE_PROFILES=$PROFILES docker compose -f $DOCKER_COMPOSE_FILE up -d
# COMPOSE_PROFILES=$PROFILES docker compose -f $DOCKER_COMPOSE_FILE up $DETACH

echo "Docker Compose started"
