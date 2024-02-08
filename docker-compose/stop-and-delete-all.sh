#!/bin/bash

# Script to stop all services, delete all containers, networks volumes and images of the Compose file.

# -v --> include named volumes declared in the "volumes" section of the Compose file and anonymous volumes attached to containers.
docker compose down -v
docker rmi -f $(docker compose images -q)
yes | docker system prune -a
# docker volume rm $(docker volume ls -q)       # This would delete also other volumes.
# docker network rm $(docker network ls -q -f name=adempiere-all.adempiere_network)  # not necessary
