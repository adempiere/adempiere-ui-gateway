
## Installation

> **💡 Important: No Java Installation Required**
>
> You do NOT need to install Java, JDK, or any Java tools on your host machine.
> Java runs inside the Docker containers and is already included in the images.
> This is one of the main benefits of using Docker!

### Automated Server Deployment

> **Deploying on a fresh VPS or dedicated server?** The [**adempiere-deployment-and-installation**](https://github.com/adempiere/adempiere-deployment-and-installation) Ansible project automates OS hardening, Docker installation, repository clone, and application start with health check — no manual steps required on the target server.
>
> The steps below cover the **manual** setup for a machine where Docker and Git are already installed.

---

### Index

| Step | Description |
|------|-------------|
| [1. Requirements](#1-requirements) | Tools to install and version checks |
| [2. Clone This Repository](#2-clone-this-repository) | Get the code |
| [3. Switch to the Correct Branch](#3-switch-to-the-correct-branch) | Ensure you're on the right branch |
| [4. Automatic Execution](#4-automatic-execution) | One-script start, result, and restore cases |
| [5. Manual Execution](#5-manual-execution) | Step-by-step manual setup |
| [6. Post-Installation: Initialize the Vue Menu](#6-post-installation-initialize-the-vue-menu) | Export dictionary, rebuild OpenSearch index |
| [7. Stop All Services](#7-stop-all-services-that-were-started-with-script-start-allsh) | How to stop the running stack |
| [8. Delete All Docker Objects](#8-delete-all-docker-objects) | Full cleanup including volumes |
| [9. Database Access](#9-database-access) | Connect to PostgreSQL |
| [10. PGAdmin Access with SSH Certificate](#10-pgadmin-access-with-ssh-certificate) | PGAdmin access via SSH identity file |

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
- `POSTGRES_IMAGE` -> the PostgreSQL version to use (default: `postgres:14.5`). This is the **single source of truth** for the Postgres version — it controls both the `docker-compose.yml` service definition and the `postgresql/postgres.Dockerfile` base image.
- `ADEMPIERE_GITHUB_VERSION` -> the ADempiere DB seed version.
- `ADEMPIERE_GITHUB_COMPRESSED_FILE` -> the DB seed archive name.

Values in file **env_template.env**:
> CLIENT_NAME="adempiere-ui"
>
> COMPOSE_PROJECT_NAME=${CLIENT_NAME}-gateway
>
> HOST_IP=<your-host-ip-or-domain>
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

### 6. Post-Installation: Initialize the Vue Menu

> **This step is mandatory after every fresh installation or database restore.**
> Without it, the Vue UI (`/vue`) will show a truncated menu with folder nodes only — no windows, processes, or reports.

**Why this is needed:** `dictionary-rs` subscribes to Kafka topics at startup. On a fresh installation the topics do not exist yet, so `dictionary-rs` misses the initial rebalance. After the export creates the topics, `dictionary-rs` must be restarted so it can subscribe and consume correctly.

#### Step 6a — Delete any stale OpenSearch menu indices

```bash
cd /opt/development/adempiere-ui-gateway/docker-compose

# Allow wildcard deletion (required by OpenSearch)
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s -X PUT 'http://localhost:9200/_cluster/settings' \
  -H 'Content-Type: application/json' \
  -d '{"persistent":{"action.destructive_requires_name":false}}'

# Delete all menu indices
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s -X DELETE 'http://localhost:9200/menu*'
```

#### Step 6b — Export Application Dictionary in ZK

Open **http://\<HOST_IP\>/webui** → log in → go to:
**System Admin → Application Dictionary → Export Application Dictionary**

Enable **all** of the following in a **single run**:

| Option | Notes |
|--------|-------|
| ✅ Export Tree | Critical — easy to forget |
| ✅ Export Menu / Menu Items | |
| ✅ Export Windows | |
| ✅ Export Processes | |
| ✅ Export Browsers | |
| ✅ Export Forms | |
| ✅ Export Roles | |

> **"Commit Failed" message:** If the export ends with `** Created XXXX Commit Failed.`, this is **cosmetic**. The Kafka messages are sent before the final database commit. The data is in Kafka. Verify with:
> ```bash
> sudo docker exec adempiere-ui-gateway.kafka \
>   kafka-topics --bootstrap-server localhost:9092 --list
> ```
> All 7 topics must appear: `browser`, `form`, `menu_item`, `menu_tree`, `process`, `role`, `window`.

Do **not** restart the stack after the export — `dictionary-rs` must be running to consume the messages.

#### Step 6c — Restart dictionary-rs

```bash
sudo docker restart adempiere-ui-gateway.dictionary-rs
```

#### Step 6d — Wait for consumption to complete

```bash
sudo docker container logs -f adempiere-ui-gateway.dictionary-rs 2>&1 | grep -v 'Offsets committed'
```

Wait until the `menu_item` indices appear and stabilize in OpenSearch (takes ~10–15 minutes; `menu_item` is the largest topic with ~1000 messages):

```bash
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s 'http://localhost:9200/_cat/indices?v' | grep 'menu_item'
```

Expected result when done (doc counts stable, no longer increasing):
- `menu_item_en_us` / `menu_item_es_sv`: ~1000 docs each
- `menu_tree`: ~6 docs
- `role_*` indices: present

#### Step 6e — Reload nginx

```bash
sudo docker exec adempiere-ui-gateway.nginx-ui-gateway nginx -s reload
```

This forces nginx to re-resolve the `dictionary-rs` hostname after the restart.

#### Step 6f — Verify

Open **http://\<HOST_IP\>/vue**, log in, and confirm the full menu appears with windows, processes, and reports.

If the menu is still incomplete, see [troubleshooting.md — Vue Menu Empty After Database Restore](./troubleshooting.md#vue-menu-empty-after-database-restore).

---

### 7. Stop All Services That Were Started With Script start-all.sh
To stop all Docker containers that were started with script `start-all.sh`, just execute:
```Shell
cd docker-compose
./stop-all.sh
```

### 8. Delete All Docker Objects
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

### 9. Database Access
Connect to the database via port **55432** with a DB connector, e.g. PGAdmin.
Or use the port defined by the variable `POSTGRES_EXTERNAL_PORT` in `env_template.env`.
It is recommended to configure PGAdmin access with an SSH certificate (see [Step 10](#10-pgadmin-access-with-ssh-certificate) below).
For context on why port 55432 is exposed, see [Architecture — Port Exposure Strategy](./architecture.md#port-exposure-strategy).

### 10. PGAdmin Access with ssh certificate

**Step 1 — Generate an SSH key pair on the machine running PGAdmin and deploy it to the host:**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/pgadmin_tunnel
ssh-copy-id -i ~/.ssh/pgadmin_tunnel.pub username@<host-ip>
```

The private key `~/.ssh/pgadmin_tunnel` is what you will reference in the PGAdmin Identity File field below.

**Step 2 — Configure the PGAdmin server connection:**

- Connection/Hostname: localhost
- Connection/Port: the port defined in `env_template.env` variable `POSTGRES_EXTERNAL_PORT`. Default is 55432
- Connection/Maintenance database: postgres
- Parameters/SSL Mode: [keyword: ssl] [Value: prefer]
- Parameters/Connection Timeout: e.g. 10 seconds
- SSH Tunnel/Use SSH Tunneling: Active
- SSH Tunnel/Tunnel Host: `<IP where the host is running ssh>`
- SSH Tunnel/Tunnel Port: 22 (default; you can switch to another port if needed)
- SSH Tunnel/Username: `<username on the host matching the deployed SSH key>`
- SSH Tunnel/Authentication: Identity File
- SSH Tunnel/Identity File: `~/.ssh/pgadmin_tunnel`




---

[Back to README](../README.md) | [Previous: Profiles](./profiles.md) | [Next: Services](./services.md)

