
## Installation

> **💡 Important: No Java Installation Required**
>
> You do NOT need to install Java, JDK, or any Java tools on your host machine.
> Java runs inside the Docker containers and is already included in the images.
> This is one of the main benefits of using Docker!

### 1. Requirements

#### Install Tools
Make sure to install the following on your host machine:
- [Docker](https://docs.docker.com/engine/install/)
- [Docker Compose v2.16.0 or later](https://docs.docker.com/compose/install/linux/)
- [Git](https://git-scm.com/downloads)
- [Python 3.10 or later](https://www.python.org/downloads/) (required for `docker-compose/generate_env.py`; Python 3.11 recommended)

**What you DON'T need:** Java/JDK, PostgreSQL, nginx, or any application servers - these all run inside the containers.

**Security benefit:** Keeping these services isolated in containers minimizes your host's attack surface. If vulnerabilities exist in containerized software, they cannot directly compromise your host system - this is a key security advantage of Docker.

#### Check Versions
Check `docker version`:
```Shell
docker --version
    Docker version 23.0.3, build 3e7cbfd
```
Check `docker compose version`:
```Shell
docker compose version
    Docker Compose version v2.17.2
```

### 2. Clone This Repository
```Shell
git clone https://github.com/adempiere/adempiere-ui-gateway
cd adempiere-ui-gateway
```

### 3. Switch to the Correct Branch
```Shell
git checkout main
```

### 4. Automatic Execution

#### a. Execute With One Script
Execute script `start-all.sh [all, auth, cache, report, scheduler, storage, vue, zk]`:

```shell
cd docker-compose
```

- Default/Standard profile/stack:
```shell
./start-all.sh
```
Or:
```shell
./start-all.sh -d default
```

- Authentication (`auth`) profile/stack:
```shell
./start-all.sh -d auth
```

- Dictionary Cache (`cache`) profile/stack:
```shell
./start-all.sh -d cache
```

- Report Engine (`report`) profile/stack:
```shell
./start-all.sh -d report
```

- Processor Scheduler (`scheduler`) profile/stack:
```shell
./start-all.sh -d scheduler
```

- S3 Storage (`storage`) profile/stack:
```shell
./start-all.sh -d storage
```

- ADempiere-Vue UI (`vue`) profile/stack:
```shell
./start-all.sh -d vue
```

- ADempiere-Zk UI (`zk`) profile/stack:
```shell
./start-all.sh -d zk
```

The script `start-all.sh [parameter]` carries out the steps of the automatic installation.

Depending on the parameter -that BTW selects the profile- the script assembles the services out of file **docker-compose.yml** by including to the project only the services that have the profile set.

If no flag and/or parameter is given, the call will default to `docker compose -f docker-compose.yml` for the services combination **all**.
If directories `postgresql/postgres_database` and `postgresql/backups` do not exist, they are created.

#### b. Result Of Script Execution
The docker compose project is executed with only services that have the profile given as parameter to the script `./start-all.sh`.

  Depending on the profile passed, certain services will be executed. This depends on the purpose/mode: for example when testing Vue, the combination is different than for Authentication.

  All images are downloaded, containers and other docker objects created, containers are started, and -depending on conditions explained in the following section- database restored.

This might take some time, depending on your bandwith and the size of the restore file.
Once the image have been downloaded, the container creation and start will last less than without downloading.

#### c. Cases When Database Will Be Restored
If
- there is a file *seed.backup* (or as defined in `env_template.env`, variable `POSTGRES_RESTORE_FILE_NAME`) in directory `postgresql/backups`, and
- the database as specified in `env_template.env`, variable `POSTGRES_DATABASE_NAME` does not exist in Postgres, and
- directory `postgresql/postgres_database` does not exist.

*The database  will be restored*.

#### d. Cases When Database Will Not Be Restored
The execution of `postgresql/initdb.sh` will be skipped if
- directory `postgresql/postgres_database` has contents, or
- in file `docker-compose.yml` there is a definition for *image*.
  Here, the Dockerfile is ignored and thus also `docker-compose.yml`.



### 5. Manual Execution
Alternative to **Automatic Execution**.
Recommendable for the first installation.

#### a. Create the directory on the host where the database will be mounted
```shell
mkdir postgresql/postgres_database
```

#### b. Create the directory on the host where the backups will be mounted
```shell
mkdir postgresql/backups
```

#### c. Copy backup file (if restore is needed)
- If you are executing this project for the first time or you want to restore the database, execute a database backup.
- First, go to the backups directory
  _cd .../adempiere-ui-gateway/docker-compose/postgresql/postgres_backups_
- Here you can run a backup directly from host using the _docker exec_ command
  _docker exec -i adempiere-ui-gateway.postgresql pg_dump --no-owner -h localhost -U postgres adempiere > adempiere-$(date '+%Y-%m-%d').backup_
- Or you can go into the container with _docker exec -it adempiere-ui-gateway.postgresql bash_ and execute there a backup e.g.: `cd /home/adempiere/postgres_backups` followed by `pg_dump -v --no-owner -h localhost -U postgres <DB-NAME> > adempiere-$(date '+%Y-%m-%d').backup`. Remember to first change directory to the shared directory between host and Postgres container.
- The file can have the name you wish, but if you want to execute a restore, it must be named `seed.backup` or as it was defined in *env_template.env*, variable `POSTGRES_RESTORE_FILE_NAME`.
  The backup file should be visible under `adempiere-ui-gateway/postgresql/backups`. You can copy it for safety reasons to other location e.g. the cloud.
- Make sure it is not the compressed backup (e.g. .jar).
- The database directory `adempiere-ui-gateway/docker-compose/postgresql/postgres_database` must be non-existing for the restore to ocurr.
  A backup will not ocurr if the database directory exists or has contents.
```shell
cp <PATH-TO-BACKUP-FILE> postgresql/backups
```

#### d. Modify configuration as needed

**Recommended:** copy `override_template.env` to `override.env` and edit only what you need to change. `override.env` is git-ignored, so local values are never accidentally committed.

```shell
cp override_template.env override.env
nano override.env
```

Alternatively, edit `env_template.env` directly. The variables most commonly changed are:
- `COMPOSE_PROJECT_NAME` -> the name of your project/client; all container names are derived from this.
- `HOST_IP` -> the IP address or domain of your host.
- `POSTGRES_IMAGE` -> the Postgres version to use.
- `ADEMPIERE_GITHUB_VERSION` -> the ADempiere DB seed version.
- `ADEMPIERE_GITHUB_COMPRESSED_FILE` -> the DB seed archive name.

Values in file **env_template.env**:
> CLIENT_NAME="adempiere-ui"
>
> COMPOSE_PROJECT_NAME=${CLIENT_NAME}-gateway
>
> HOST_IP=192.268.0.246
>
> HOST_URL=http://${HOST_IP}
>
> ADEMPIERE_NETWORK=${COMPOSE_PROJECT_NAME}.network
>
> NETWORK_SUBNET=192.168.100.0/24
>
> NETWORK_GATEWAY=192.168.100.1
>
> NETWORK_IP_RANGE=192.168.10.0/24
>
> ALLOWED_ORIGIN=${HOST_IP}

Other values in *env_template.env* are default values.
Feel free to change them accordingly to your wishes/purposes.
There should be no need to change file `docker-compose.yml`.

#### e. env_template.env and .env
Once you have modified *env_template.env* as needed, run `start-all.sh` — it will automatically generate `.env` from `env_template.env` (and `override.env` if present) before starting Docker Compose. **Do not copy `env_template.env` to `.env` manually.**

#### f. File initdb.sh (optional)
Modify `postgresql/initdb.sh` as necessary, depending on what you may want to do at database first start.
You may create roles, schemas, etc.

#### g. Execute docker compose
```shell
./start-all.sh
```

**Result: all images are downloaded, containers and other docker objects created, containers are started, and database restored**.

This might take some time, depending on your bandwith and the size of the restore file.

### 6. Stop All Services That Were Started With Script start-all.sh
To stop all Docker containers that were started with script `start-all.sh`, just execute:
```Shell
cd docker-compose
./stop-all.sh
```

### 7. Delete All Docker Objects
Sometimes, due to different reasons, you need to undo everything you have created on Docker and start anew. This is mostly in development, not in production.
Then:
- All Docker containers must be shut down.
- All Docker containers must be deleted.
- All Docker images must be deleted.
- The Docker installation cache must be cleared.
- All Docker networks and volumes must be deleted.

Execute script:
```Shell
cd docker-compose
./stop-and-delete-all.sh
```
**Be very careful when using this script, because it will delete all Docker objects you have!**

### 8. Database Access
Connect to database via port **55432** with a DB connector, e.g. PGAdmin.
Or to the port the variable `POSTGRES_EXTERNAL_PORT` points in file `env_template.env`.
It is recommendable to configure the PGAdmin access with ssh certification.

### 9. PGAdmin Access with ssh certificate
First step: generate a ssh certificate for a host's user and deploy it on the host

PGAdmin Server Configuration
- Connection/Hostname: localhost
- Connection/Port: the port defined in file _env_template.env_ variable `POSTGRES_EXTERNAL_PORT`. Default is 55432
- Connection/Maintenance database: postgres
- Parameters/SSL Mode: [keyword: ssl] [Value: prefer]
- Parameters/Connection Timeout: e.g. 10 seconds
- SSH Tunnel/Use SSH Tunneling: Active
- SSH Tunnel/Tunnel Host: <IP where host is running ssh>
- SSH Tunnel/Tunnel Port: 22 (default; you can swith to another port if needed)
- SSH Tunnel/Username: <Username of host according to ssh certificate>
- SSH Tunnel/Authentication: Identity File
- SSH Tunnel/Identity File: <Path to ssh certificate>




---

[Back to README](../README.md) | [Previous: Profiles](./profiles.md) | [Next: Services](./services.md)

