#!/bin/bash

# Script to stop all services, delete all containers, networks volumes and images of the Docker Compose file.
while true; do
    read -p "Do you wish to delete ALL Docker objects (this can't be undone)? " yn
    case $yn in
        [Yy]* ) echo -e "All Docker objects will be deleted!!\n"
                DOCKER_COMPOSE_FILE=docker-compose.yml
                echo "All services started with the Docker Compose file \"$DOCKER_COMPOSE_FILE\" will be stopped!"
                # -v --> include named volumes declared in the "volumes" section of the Compose file and anonymous volumes attached to containers.
                docker compose -f $docker_compose_file down -v

                # To avoid misunderstandings, the Docker Compose file is deleted.
                # It may be created again by calling "start-all.sh".
                if [ -e $DOCKER_COMPOSE_FILE ]
                then
                    rm $DOCKER_COMPOSE_FILE
                fi

                docker rmi -f $(docker compose images -q)
                yes | docker system prune -a
                # docker volume rm $(docker volume ls -q)       # This would delete also other volumes.
                # docker network rm $(docker network ls -q -f name=adempiere-all.adempiere_network)  # not necessary

                break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


