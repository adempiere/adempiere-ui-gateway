

## Architecture

### Services of Application Stack
![ADempiere All Architecture](architecture/architecture-all.png)

The services that can be executed are:
 - adempiere-site
 - adempiere-zk
 - vue-ui
 - vue-grpc-server
 - postgres-service
 - ui-gateway
 - adempiere-processor
 - dkron-scheduler
 - adempiere-grpc-server
 - adempiere-report-engine
 - s3-storage
 - s3-client
 - s3-gateway-rs
 - grpc-proxy
 - kafka
 - kafdrop
 - opensearch-node
 - opensearch-setup
 - opensearch-dashboards
 - dictionary-rs
 - keycloak
 - zookeeper


### Quick Description of Application Stack
The application stack consists of the following services defined in the *docker-compose.yml* file (and retrieved on the console with **sudo docker compose ls**); these services will eventually run as containers:
- **adempiere-site**: Defines the landing page (web site) for this application. It can be implemented as wished.
- **adempiere-zk**: Defines the Jetty server and the ADempiere ZK UI.
- **vue-ui**: Defines the new ADempiere UI with Vue.
- **vue-grpc-server**: Dedicated gRPC backend server for Vue UI.
- **postgresql-service**: Defines the Postgres database, that is persistently implemented on the host.
- **ui-gateway**: Unique access point acting as a reverse proxy and routing to redirect multiple services.
- **adempiere-processor**: For processes that are executed outside Adempiere.
- **dkron-scheduler**: A scheduler for these processes.
- **adempiere-grpc-server**: Defines a grpc server as the backend server for Vue.
- **adempiere-report-engine**: For reports.
- **s3-storage**: S3 (Simple Storage Service) for attachments and files.
- **s3-client**: S3 (Simple Storage Service) default access configuration.
- **s3-gateway-rs**: S3 (Simple Storage Service) API RESTful between ui-gateway and implemented S3 to manage files with client.
- **grpc-proxy**: API RESTful transcoding to gRPC backends.
- **opensearch-node**: Stores the Application Dictionary definitions.
- **opensearch-setup**: Configure the service *opensearch-node* and import snapshot.
- **kafka**: Messaging and streaming queue.
- **kafdrop**: A Kafka Cluster Queues Overview, Monitor and Administrator.
- **dictionary-rs**: API RESTful to manage adempiere dictionary with OpenSearch as cache.
- **opensearch-dashboards**: Display and monitor of OpenSearch indexes e.g. exported menus, smart browsers, forms, windows, processes.
- **keycloak**: User management on service *postgresql-service*.
- **zookeeper**: Controller for *kafka* service.

Additional objects defined in the *docker-compose files*:
- `adempiere_network`: defines the subnet used in the involved Docker containers (e.g. **192.168.100.0/24**)
- `volume_postgres`: defines the mounting point of the Postgres database (typically directory **/var/lib/postgresql/data**) to a local directory on the host where the Docker container runs. This implements a persistent database.
- `volume_backups`: defines the mounting point for a backup (or restore) directory on the Docker container to a local directory on the host where the Docker container has access. It can be used for backup or restre purposes.
- `volume_persistent_files`: mounting point for the ZK container
- `volume_scheduler`: defines the mounting point for the scheduler (`TO BE IMPLEMENTED YET`)

### File Structure
- *README.md*: the main documentation file.
- *env_template.env*: template for definition of all variables used in docker composed files. Usually, this file is edited for testing and copied to *.env* before running docker compose. Please remember that the file Docker Compose needs to run is *.env*.
- *docker-compose.yml*: Defines multple services, with different configurations for different purposes/modes as profiles/stacks. These are controlled by profiles.
- `start-all.sh`: First of all, the persistent directory (database) and the backup directory are created if not existent. The profiles is set depending on the input parameter; then the file *env_template.env* is copied to *.env* and eventually Docker Compose is started for the file `docker-compose.yml`.
- `stop-all.sh`: shell script to automatically stop all services that were started with the script `start-all.sh` and defined in file `docker-compose.yml`.
- `stop-and-delete-all.sh`: shell script to delete **all** containers, images, networks, cache and volumes, **including the ones** created without `start-all.sh` or by executing `docker-compose.yml`.
**Be very careful when using this script, because it will reset and delete everything you have of Docker** excepting the database and other persistent volumes.
    After executing this shell, no trace of the application will be left over. Only the persistent directory will not be affected, which must be manually deleted on the host if desired.
- `postgresql/Dockerfile`: the Dockerfile used.
  It mainly copies `postgresql/initdb.sh` to the container, so it can be executed at start.
- `postgresql/initdb.sh`: shell script executed when Postgres starts.
  If there is a database named `adempiere`, nothing happens.
  If there is no database named `adempiere`, the script checks if there is a database seed file in the backups directory.
  - If there is one, it launches a restore database.
  - If there is none, the latest ADempiere seed is downloaded from Github and the restore is started with it.
- `postgresql/postgres_database`: directory on host used as the mounting point for the Postgres container's database.
  It implements persistence: this makes sure that the database is not deleted even if the docker containers, docker images and even docker are deleted.
  The database contents are always kept persistently on the host.
- `postgresql/backups`: directory on host used as the mounting point for the `backups/restores` from the Postgres container.
  Here the seed file for a potential restore can be copied and eventually transferred via sftp or scp to anther place.

  The name of the seed can be defined in `env_template.env`.
  The seed is a backup file created with psql.
  If there is a seed, but a database exists already, there will be no restore.

  This directory may also be useful when creating a backup: it can be created here, without needing to transfer it from the container to the host.
- `postgresql/persistent_files`: directory on host used for persistency with the ZK container. It allows to share files bewteen the host and the ZK container.
- *docs*: directory containing images and documents used in this README file.



### Images
Before running containers, images mus be downloaded and containers created out of these images.
Image versions used in file *docker-compose.yml*, to be found in DockerHub.
The actual version is defined in file *env_template.env*.

| Image                               | Image Name                                   |  Tag (Version)                        |
| ----------------------------------- |:--------------------------------------------:|:-------------------------------------:|
| PostgreSQL                          | postgres                                     | 14.5                                  |
| Main Page                           | openls/adempiere-landing-page (1)            | alpine-1.0.3                          |
| OpenSearch API RESTful              | openls/dictionary-rs  (2)                    | 1.5.5                                 |
| ADempiere Report Engine             | openls/adempiere-report-engine-service (2)   | alpine-1.3.7                          |
| S3 Minio Client/Storage             | quay.io/minio/minio                          | RELEASE.2024-07-31T05-46-26Z          |
| DKron Task Scheduler                | dkron/dkron                                  | 3.2.7                                 |
| Zookeeper for Kafka Brokers         | confluentinc/cp-zookeeper                    | 7.6.1                                 |
| Kafka Queue Manager                 | confluentinc/cp-kafka                        | 7.6.1                                 |
| Kafdrop Kafka Cluster Overview      | obsidiandynamics/kafdrop                     | 4.0.1                                 |
| OpenSearch Search Engine            | opensearchproject/opensearch                 | 2.15.0                                |
| OpenSearch Dashboards UI            | opensearchproject/opensearch-dashboards      | 2.15.0                                |
| NGINX UI Gateway                    | nginx                                        | 1.27.0-alpine3.19                     |
| Keycloak ID & Access Management     | keycloak/keycloak                            | 23.0.7                                |
| ADempiere Vue Backend (gRPC Server) | marcalwestf/adempiere-grpc-server (3)        | 3.9.4.001-shw-1.0.25                  |
| Proxy for Processors/Backend        | marcalwestf/adempiere-grpc-server-proxy (3)  | 3.9.4.001-shw-1.0.25                  |
| Adempiere ZK UI                     | marcalwestf/adempiere-shw-zk (3)             | jetty-3.9.4.001-shw-1.1.27            |
| ADempiere Processors gRPC Server    | marcalwestf/adempiere-processors-service (3) | alpine-1.1.2                          |
Notes:
(1) The landing page can be in your favorite image
(2) These Images will in future be in *adempiere* instead of *openls*
(3) These are images that contain the costumizations. The *Image Name* will be the repository where the customization is implemented; mostly the own repository.


### User's perspective
From a user's point of view, the application consists of the following.
Take note that the ports are defined in file *env_template.env* as external ports and can be changed if needed or desired.
- A home web site, accessible via port **80**
  From which all applications can be called
- An ADempiere ZK UI, accessible via path **/webui**
- An ADempiere Vue UI, accessible via path **/vue**
- A Postgres database, accessible e.g. by PGAdmin via port **55432**
- An OpenSearch Dashboard, accessible via port **5601**
- Access to Kafka Queue via port **29092**
- A Kafdrop Kafka Queue Monitor and Administrator, accessible via port **19000**
- A DKron browser for monitoring scheduled jobs, accessible via port **8899**
- A MinIO Console (actually a browser) for monitoring objects stored (like files, reports, images), accessible via port **9090**

Beware that **image versions may change ongoing**.


[Back to README](../README.md)  | [Previous: System Requirements](./system-requirements.md) | [Next: Profiles](./profiles.md)
