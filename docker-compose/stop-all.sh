#!/bin/bash

# Script to stop all services of the Compose file.
# The file must be called for stopping the services

savefile=.DOCKER_COMPOSE_FILE
if [ -e $savefile ]
then
    docker_compose_file=$(cat $savefile)
else
    docker_compose_file=docker-compose.yml
fi

echo "All services started with the Docker Compose file \"$docker_compose_file\" will be stopped"
docker compose -f $docker_compose_file down

# To avoid misunderstandings, the file is deleted
if [ -e $savefile ]
then
    rm $savefile
fi
