#!/bin/bash

# Script to stop all services started with the Docker Compose file.
# The services were called with this Docker Compose file via script "start-all.sh".

DOCKER_COMPOSE_FILE=docker-compose.yml

echo "All services started with the Docker Compose file \"$DOCKER_COMPOSE_FILE\" will be stopped!"
docker compose -f $DOCKER_COMPOSE_FILE down

# Clean up .env to ensure fresh generation on next start
if [ -f .env ]; then
    echo 'Removing .env file to ensure fresh configuration on next start'
    rm -f .env
fi
