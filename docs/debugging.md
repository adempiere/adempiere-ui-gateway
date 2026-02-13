

## Useful Commands
This application uses **Docker Compose** and as such, all docker and docker compose commands can be called to work with it.
### Container Management
##### Shut Down All Containers
  All containers started with the -f flag file will be stopped and destroyed; the database will be preserved.
  All docker images, networks, and volumes will be preserved.
```Shell
sudo docker compose down
```
##### Stop and Delete One Service (services defined in *docker-compose* files)
```Shell
sudo docker compose rm -s -f <service name>
sudo docker compose rm -s -f postgresql-service
sudo docker compose rm -s -f adempiere-zk
etc.
```
##### Stop And Delete All Services
```Shell
sudo docker compose rm -s -f
```
##### Create And Restart All Services
```Shell
sudo docker compose up -d
```
##### Stop One Single Service
```Shell
sudo docker compose stop <service name>
sudo docker compose stop adempiere-site
etc.
```
##### Start One Single Service (after it was stopped)
```Shell
sudo docker compose start <service name>
sudo docker compose start adempiere-site
etc.
```
##### Start And Stop One Single Service
```Shell
sudo docker compose restart <service name>
sudo docker compose restart adempiere-site
etc.
```
##### Find Containers And Services
```Shell
sudo docker compose ps -a
```

### Misc Commands
##### Display all Services (docker compose must run; otherwise error "no configuration file provided: not found")
```Shell
sudo docker compose config --services
```


##### Display All Docker Images
```Shell
sudo docker images -a
```

##### Display All Docker Containers Started with Docker Compose
```Shell
sudo docker compose ps -a
sudo docker compose ps -a --format "{{.ID}}: {{.Names}}"
```

##### Display All Docker Containers
```Shell
sudo docker ps -a
sudo docker ps -a --format "{{.ID}}: {{.Names}}"
```

##### Debug I: Display Values To Be Used In Application
Renders the actual data model to be applied on the Docker engine by merging `env_template.env` and `docker-compose.yml`.
If you have modified *env_template.env*, make sure to copy it to `.env`.

```shell
cp env_template.env .env
sudo docker compose convert
```

##### Debug II: Display Container Logs
```shell
sudo docker container logs <CONTAINER>                         -->> variable defined in *env_template.env*
sudo docker container logs <CONTAINER> | less                  -->> variable defined in *env_template.env*
sudo docker container logs adempiere-ui-gateway.postgres
sudo docker container logs adempiere-ui-gateway.postgres | less

```

##### Debug III: Display Container Values
Display the values a container is working with.
```Shell
sudo docker container inspect <CONTAINER>
sudo docker container inspect adempiere-ui-gateway.postgres
sudo docker container inspect adempiere-ui-gateway.zk
etc.

```

##### Debug IV: Log Into Container
```Shell
sudo docker container exec -it <CONTAINER> <SHELL_TO_BE_USED>
sudo docker container exec -it adempiere-ui-gateway.postgres bash
etc.

```
Caveat: some containers use _sh_ instead of _bash_.

##### Debug V: Run a Command in a Container From Outside
```Shell
sudo docker container exec -it <CONTAINER> <COMMAND>
sudo docker container exec -it adempiere-ui-gateway.postgres date
etc.

```

##### Delete Database On Host I (Using Docker File System)
Physically delete database from the host via Docker elements.
Sometimes it is needed to delete all files that comprises the database.
Be careful with these commands, once done, there is no way to undo it!
The database directory must be empty for the restore to work.
```Shell
sudo ls -al /var/lib/docker/volumes/<POSTGRES_VOLUME>                     -->> variable defined in *env_template.env*
sudo ls -al /var/lib/docker/volumes/adempiere-ui-gateway.volume_postgres  -->> default value

sudo rm -rf /var/lib/docker/volumes/<POSTGRES_VOLUME>/_data
sudo rm -rf /var/lib/docker/volumes/adempiere-ui-gateway.volume_postgres/_data
```

##### Delete Databse On Host II (using mounted volume on host)
Physically delete database from the host via mounted volumes.
Sometimes it is needed to delete all files that comprises the database.
Be careful with these commands, once done, there is no way to undo it!
The database directory must be empty for the restore to work.
```Shell
sudo ls -al <POSTGRES_DB_PATH_ON_HOST>                         -->> variable defined in *env_template.env*
sudo ls -al <PATH TO REPOSITORY>/postgresql/postgres_database  -->> default value

sudo rm -rf <POSTGRES_DB_PATH_ON_HOST>
sudo rm -rf <PATH TO REPOSITORY>/postgresql/postgres_database
```


[Back to README](../README.md) | [Previous: Security](./security.md) | [Next: Troubleshooting](./troubleshooting.md)
