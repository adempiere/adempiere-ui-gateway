#!/bin/bash

# Script to stop all services, delete all containers, networks volumes and images of the Docker Compose file.

savefile=.DOCKER_COMPOSE_FILE
if [ -e $savefile ]
then
    docker_compose_file=$(cat $savefile)
else
    docker_compose_file=docker-compose.yml
fi

echo "All services started with the Docker Compose file \"$docker_compose_file\" will be stopped"
# -v --> include named volumes declared in the "volumes" section of the Compose file and anonymous volumes attached to containers.
docker compose -f $docker_compose_file down -v

# To avoid misunderstandings, the file is deleted
if [ -e $savefile ]
then
    rm $savefile
fi

docker rmi -f $(docker compose images -q)
yes | docker system prune -a
# docker volume rm $(docker volume ls -q)       # This would delete also other volumes.
# docker network rm $(docker network ls -q -f name=adempiere-all.adempiere_network)  # not necessary
