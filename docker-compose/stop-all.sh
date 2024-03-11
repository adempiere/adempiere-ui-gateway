#!/bin/bash

# Script to stop all services started with the Docker Compose file.
# The services were called with this Docker Compose file via script "start-all.sh".

DOCKER_COMPOSE_FILE=docker-compose.yml

echo "All services started with the Docker Compose file \"$DOCKER_COMPOSE_FILE\" will be stopped!"
docker compose -f $DOCKER_COMPOSE_FILE down

# To avoid misunderstandings, the Docker Compose file is deleted.
# It may be created again by calling "start-all.sh".
if [ -e $DOCKER_COMPOSE_FILE ]
then
    rm $DOCKER_COMPOSE_FILE
fi
