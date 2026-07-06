
## Index

| Section | Description |
|---------|-------------|
| [Overview](#overview) | Key technologies and deployment model |
| [Architecture](#architecture) | Full stack architecture breakdown |
| [Services of Application Stack](#services-of-application-stack) | All services and their roles |
| [Quick Description of Application Stack](#quick-description-of-application-stack) | Service summary table |
| [Network Architecture](#network-architecture) | Container networking and traffic flow |
| [Repository Structure](#repository-structure) | Directory layout |
| [File Structure](#file-structure) | Key files and their purpose |
| [Health Checks and Startup Order](#health-checks-and-startup-order) | How containers wait for dependencies; health-check.sh and full-restart-with-healthcheck.sh |
| [Images](#images) | Docker image versions |
| [Data Persistence](#data-persistence) | Where the database lives on the host and why it survives container removal |
| [User's perspective](#users-perspective) | SSH tunnel for remote access |

---

## Overview

The **ADempiere UI Gateway** is a Docker Compose-based stack for running ADempiere ERP with multiple UI options (ZK and Vue), integrated services, and a complete microservices architecture. The stack uses nginx as a reverse proxy/API gateway to route requests to various backend services.

**Key Technologies:**
- Docker Compose (v2.16.0+)
- PostgreSQL 14.5 (database)
- nginx (API gateway/reverse proxy with JavaScript and Lua support)
- ADempiere ZK (classic UI)
- ADempiere Vue (modern UI)
- gRPC backend services with Envoy proxy
- OpenSearch (dictionary cache)
- Kafka + Zookeeper (messaging)
- MinIO S3 (file storage)
- Keycloak (authentication — optional)
- DKron (job scheduling)

---

## Architecture

### Services of Application Stack
![ADempiere All Architecture](architecture/architecture-all.png)

The services that can be executed are:
 - adempiere-site
 - adempiere-zk
 - vue-ui
 - adempiere-grpc-server
 - postgresql-service
 - ui-gateway
 - adempiere-processor
 - dkron-scheduler
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
  - **adempiere-grpc-server**: Dedicated gRPC backend server for Vue UI. Implements the ADempiere business logic (POS, invoicing, inventory, etc.) and communicates with the database.  
  - **postgresql-service**: Defines the Postgres database, that is persistently implemented on the host.  
  - **ui-gateway**: Unique access point acting as a reverse proxy and routing to redirect multiple services.  
  - **adempiere-processor**: For processes that are executed outside Adempiere.  
  - **dkron-scheduler**: A scheduler for these processes.  
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
- `adempiere_network`: defines the subnet used by all containers (e.g. **192.168.100.0/24**).   
      Individual container IP addresses within this subnet are assigned dynamically and change every time the stack is restarted; inter-container communication must therefore use container hostnames, not IP addresses.  
- `volume_postgres`: defines the mounting point of the Postgres database (typically directory **/var/lib/postgresql/data**) to a local directory on the host where the Docker container runs. This implements a persistent database.  
- `volume_backups`: defines the mounting point for a backup (or restore) directory on the Docker container to a local directory on the host where the Docker container has access. It can be used for backup or restore purposes.  
- `volume_persistent_files`: mounting point for the ZK container  
- `volume_scheduler`: defines the mounting point for the DKron scheduler

### Network Architecture

All containers run on a custom Docker bridge network with the following configuration:

| Parameter | Default Value | Purpose |
|-----------|---------------|---------|
| **Network Name** | `adempiere-ui-gateway.network` | Isolated network for all services |
| **Subnet** | `192.168.100.0/24` | IP address range for containers |
| **Gateway** | `192.168.100.1` | Network gateway address |

**Key characteristics:**

1. **Isolated Network:** All containers communicate on a dedicated bridge network, isolated from other Docker networks
2. **DNS Resolution:** Containers can reach each other using service names (e.g., `postgresql-service`, `kafka`)
3. **Internal Communication:** Services communicate internally without exposing ports to the host
4. **Single External Entry Point:** Only nginx (port 80) is exposed to external traffic

**Communication Flow:**

```
External User (browser)
      ↓
   [Port 80]
      ↓
 ┌──────────────┐
 │    nginx     │ ← Single entry point (reverse proxy)
 │  (Gateway)   │   Path routing defined in docker-compose/nginx/api/
 └──────┬───────┘
        │ Internal network (192.168.100.0/24)
        │
        ├── /         ──→ Landing Page             (landing_page.conf)
        ├── /webui    ──→ ZK UI       (port 8080)  (adempiere_zk.conf)
        ├── /vue      ──→ Vue UI      (port 80)    (adempiere_vue.conf)
        ├── /api/     ──→ Envoy Proxy (port 5555)  (adempiere_backend.conf)
        │                     └──→ gRPC backends
        │             ↑ internal only — used by Vue Single Page Application (SPA), not a browser URL
        ├── ──────────→ OpenSearch Dashboard (port 5601)
        ├── ──────────→ Kafdrop (port 9000)
        ├── ──────────→ DKron (port 8080)
        └── ──────────→ MinIO Console (port 9090)

Internal Services (not directly exposed):
  - PostgreSQL (port 5432)
  - OpenSearch (port 9200)
  - Kafka (port 9092)
  - Zookeeper (port 2181)
  - gRPC servers (various ports)
```

The upstream definitions (which container each path routes to) are in `docker-compose/nginx/upstreams/`.

<div style="page-break-before: always;"></div>

**Detailed Request Flow — from Browser to Database:**

*SPA = Single Page Application — the Vue frontend running in the browser.*

```
┌────────────────────────────────────────────────────────────┐
│              BROWSER (Firefox / Chrome / Opera)            │
└─────────────────────────────┬──────────────────────────────┘
                              │ HTTP  port 80  [public]
                              ▼
┌────────────────────────────────────────────────────────────┐
│                      nginx  (ui-gateway)                   │
│         container: adempiere-ui-gateway.nginx-ui-gateway   │
└───────────┬──────────────────────────────┬─────────────────┘
            │ path /webui                  │ path /vue
            │ internal port 8080           │ internal port 80
            ▼                              ▼
┌─────────────────────────┐    ┌───────────────────────────────┐
│        ZK UI            │    │           Vue UI              │
│ service: adempiere-zk   │    │       service: vue-ui         │
│                         │    │  serves SPA (HTML/JS/CSS)     │
└───────────┬─────────────┘    │  to the browser               │
            │                  └───────────────────────────────┘
            │                               │
            │                        Browser runs the Vue SPA.
            │                       SPA sends API calls to port 80
            │                       (back to nginx, path /api/).
            │                       nginx routes /api/ internally to Envoy:
            │                               │ internal port 5555
            │                               ▼
            │                   ┌─────────────────────────────┐
            │                   │        Envoy Proxy          │
            │                   │     service: grpc-proxy     │
            │                   │    HTTP/JSON  ↔  gRPC       │
            │                   └───────────┬─────────────────┘
            │                               │ internal port 50059  (gRPC)
            │                               ▼
            │                   ┌────────────────────────────┐
            │                   │        gRPC Server         │
            │                   │  service: adempiere-grpc-  │
            │                   │          server            │
            │                   │  ADempiere business logic  │
            │                   ┴───────────┬────────────────┘
            │                               │ internal port 5432  (SQL)
            │                               │
            │                               │
            │                               │
            │                               ▼
            │                   ┌──────────────────────────────┐
            │                   │          PostgreSQL          │
            └──────────────────►│  service: postgresql-service │
                                │  external port 55432         │
                                └──────────────────────────────┘
```

Both ZK UI and the gRPC server connect to the same PostgreSQL instance. ZK connects diectly; the gRPC server connects on behalf of the Vue SPA.  
PostgreSQL is also reachable externally on port 55432 (e.g. from PGAdmin on the host).  
For secure remote access via PGAdmin, SSH tunneling is recommended — see [PGAdmin Access with SSH Certificate](./installation.md#10-pgadmin-access-with-ssh-certificate).

**Port Exposure Strategy:**

- **Development Mode:** Additional ports exposed for debugging (e.g., PostgreSQL 55432, Kafdrop 19000)
- **Production Mode:** Only nginx port 80 exposed; all other access goes through nginx reverse proxy

**Security Implications:**

⚠️ **Important:** Docker bypasses host firewall rules (UFW, firewalld) by manipulating iptables directly.

- Exposed ports are accessible even if the host firewall blocks them
- **Always use an external firewall** (cloud provider firewall, hardware firewall)
- Never expose the host directly to the internet without proper upstream firewall protection
- See [Security Documentation](./security.md) for detailed guidance

**Network Configuration:**

All network settings are defined in `env_template.env`:
```bash
NETWORK_SUBNET=192.168.100.0/24
NETWORK_GATEWAY=192.168.100.1
NETWORK_IP_RANGE=192.168.10.0/24
```

If these defaults conflict with an existing network on your host (e.g. your LAN already uses `192.168.100.x`), override them in `override.env`:
```bash
NETWORK_SUBNET=10.10.0.0/24
NETWORK_GATEWAY=10.10.0.1
NETWORK_IP_RANGE=10.10.0.0/24
```
The stack will use the overridden values without any changes to the versioned template.

**Troubleshooting Network Issues:**

```bash
# List Docker networks
docker network ls

# Inspect the ADempiere network
docker network inspect adempiere-ui-gateway.network

# Test connectivity between containers
docker exec adempiere-ui-gateway.vue-ui ping postgresql-service
docker exec adempiere-ui-gateway.vue-ui nc -zv kafka 9092
```

See [Troubleshooting Guide](./troubleshooting.md#network-and-access-issues) for common network problems.

For tracing errors that appear in the Vue UI back to their source in the gRPC server, see [Debugging Vue UI Errors](./debugging-vue-frontend.md).

### Repository Structure

```
docker-compose/
├── env_template.env          # Main configuration — edit this, not .env
├── override_template.env     # Template for machine-specific overrides — copy to override.env and set values
├── override.env              # (not in git) Active overrides: values here replace env_template.env defaults in .env
├── docker-compose.yml        # All service definitions with profiles (assembled by start-all.sh)
├── start-all.sh              # Start stack script (assembles docker-compose.yml, activates profiles)
├── stop-all.sh               # Stop stack script (also deletes assembled docker-compose.yml)
├── stop-and-delete-all.sh           # Complete cleanup script
├── generate-env.sh                  # Wrapper: calls generate_env.py with default paths
├── generate_env.py                  # Env generator: merges env_template.env + override.env → .env
├── health-check.sh                  # Polls all container health statuses until healthy or timeout
├── full-restart-with-healthcheck.sh # Full stop+delete+restart cycle followed by health check
├── postgresql/
│   ├── postgres_database/    # Persistent DB storage (mounted volume)
│   ├── postgres_backups/     # Backup/restore files
│   ├── persistent_files/     # ZK container shared files
│   ├── postgres.Dockerfile   # Custom Postgres image
│   └── initdb.sh             # DB initialization script (runs on first start)
├── nginx/
│   ├── nginx.conf            # Main nginx config
│   ├── api_gateway.conf      # API gateway routing
│   ├── upstreams/            # Backend service definitions
│   ├── api/                  # API endpoint configs
│   └── gateway/              # Gateway-specific configs
└── opensearch/
    └── setup_opensearch.sh   # OpenSearch initialization
```

### File Structure
- *README.md*: the main documentation file.
- *env_template.env*: template for definition of all variables used in docker composed files. Usually, this file is edited for testing and copied to *.env* before running docker compose. Please remember that the file Docker Compose needs to run is *.env*.
- *override_template.env*: git-tracked template for deployment-specific value overrides. When a variable in `env_template.env` needs a different value on a particular machine or deployment — such as a specific hostname or IP — copy this file to `override.env` and set the desired values there. Example:
  ```
  HOST_IP=my.url.com
  ```
- *override.env*: the active overrides file, **not tracked by git**. It contains a subset of variables from `env_template.env` whose values replace the template defaults when `start-all.sh` assembles `.env`. This keeps machine-specific configuration out of version control. Create it from `override_template.env` only when needed; if it does not exist, the template values are used unchanged.
- *docker-compose.yml*: Defines multple services, with different configurations for different purposes/modes as profiles/stacks. These are controlled by profiles.
- `start-all.sh`: First of all, the persistent directory (database) and the backup directory are created if not existent. The profiles is set depending on the input parameter; then the file *env_template.env* is copied to *.env* and eventually Docker Compose is started for the file `docker-compose.yml`.
- `stop-all.sh`: shell script to automatically stop all services that were started with the script `start-all.sh` and defined in file `docker-compose.yml`.
- `stop-and-delete-all.sh`: shell script to delete **all** containers, images, networks, cache and volumes, **including the ones** created without `start-all.sh` or by executing `docker-compose.yml`.
**Be very careful when using this script, because it will reset and delete everything you have of Docker** excepting the database and other persistent volumes.
    After executing this shell, no trace of the application will be left over. Only the persistent directory will not be affected, which must be manually deleted on the host if desired.
    > **Note:** Named volumes are re-created on each `start-all.sh` run but the old ones are not removed by this script. Repeated stop-and-delete/restart cycles accumulate hundreds of orphaned volumes over time. Run `docker volume prune -f` periodically to reclaim disk space. See [Troubleshooting — Orphan Volumes](./troubleshooting.md#orphan-volumes-from-repeated-startstop-cycles).
- `generate-env.sh`: convenience wrapper that calls `generate_env.py` with the default paths (`docker-compose/env_template.env`, `docker-compose/override.env`, `docker-compose/.env`). Called automatically by `start-all.sh` before each stack start.
- `generate_env.py`: Python script that merges `env_template.env` and `override.env` into the runtime `.env` file. Resolves `${VAR}` references recursively and aborts if any required value is still set to `__CHANGE_ME__`. Supports `--dry-run` (prints resolved output without writing) and `--help`.
- `health-check.sh`: polls the health status of all containers at regular intervals and reports which services are healthy, starting, or unhealthy. Used to confirm the stack is fully up after a start or restart.
- `full-restart-with-healthcheck.sh`: performs a complete stop-and-delete cycle followed by a fresh stack start, then runs `health-check.sh` to confirm all services reach a healthy state.
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
- `postgresql/postgres_backups`: directory on host used as the mounting point for the `backups/restores` from the Postgres container.
  Here the seed file for a potential restore can be copied and eventually transferred via sftp or scp to anther place.

  The name of the seed can be defined in `env_template.env`.
  The seed is a backup file created with psql.
  If there is a seed, but a database exists already, there will be no restore.

  This directory may also be useful when creating a backup: it can be created here, without needing to transfer it from the container to the host.
- `postgresql/persistent_files`: directory on host used for persistency with the ZK container. It allows to share files bewteen the host and the ZK container.
- *docs*: directory containing images and documents used in this README file.



### Health Checks and Startup Order

The stack uses Docker Compose health checks to ensure services start in the correct order and are fully operational before dependent services connect to them.

#### Health Check Configuration

Health checks verify that a service is ready to accept connections. They run periodically and determine the service's health status.

**Key services with health checks:**

| Service | Health Check | Startup Time | Retry Tolerance |
|---------|--------------|--------------|-----------------|
| **PostgreSQL** | Database query + version check | 10-30 seconds | 3 minutes |
| **OpenSearch** | HTTP connection test | 60-120 seconds | 5 minutes |
| **Kafka** | Topic list command | 60-90 seconds | 4 minutes |
| **Zookeeper** | Status check | 10-20 seconds | 2.5 minutes |

**Why some services take longer to start:**

- **OpenSearch (60-120s):** Java service initialization, index loading, cluster coordination
- **Kafka (60-90s):** Java service initialization, broker startup, ZooKeeper connection
- **PostgreSQL (10-30s):** Database initialization, especially on first restore

**Total stack startup time:** 90-120 seconds is normal and expected.

#### Health Check Parameters

Each health check has four key parameters:

- **interval:** How often to run the check (e.g., every 30 seconds)
- **timeout:** Max time for check to complete (e.g., 10 seconds)
- **retries:** How many failures before marking unhealthy (e.g., 10 retries)
- **start_period:** Grace period before health checks start (e.g., 40 seconds)

**Example:** PostgreSQL health check
- Checks every 30 seconds
- Allows 10 retries = 300 seconds (5 minutes) total tolerance
- 40-second grace period before first check
- Result: Up to 5.5 minutes for PostgreSQL to become healthy

These relaxed timeouts accommodate:
- Database restoration on first start
- Large index loading
- Network latency
- Resource contention during initial startup

**Recommended values by service type:**

| Service type | `interval` | `retries` | `start_period` | Total tolerance |
|---|---|---|---|---|
| Fast services (web servers, simple APIs) | 30s | 3–5 | 10–20s | ~2.5 min |
| Database services (PostgreSQL) | 30s | 10 | 40s | ~5.5 min |
| Search/analytics (OpenSearch) | 30s | 10 | 40s | ~5.5 min |
| Messaging/coordination (Kafka, Zookeeper) | 30s | 8 | 30s | ~4.5 min |

**Anti-patterns to avoid:**
- Reducing health check intervals to speed up startup — the service needs actual initialization time regardless
- Removing `depends_on` entries to parallelize startup — this breaks proper initialization order
- Very short timeouts in production — causes cascade failures

#### Service Dependencies

Services use `depends_on` with health check conditions to ensure proper startup order:

```
┌─────────────────────────────────────────────────────┐
│                   Startup Order                     │
└─────────────────────────────────────────────────────┘

Layer 1 (Infrastructure):
  ┌──────────────┐  ┌──────────────┐
  │ PostgreSQL   │  │  Zookeeper   │
  │ (database)   │  │  (Kafka mgr) │
  └──────┬───────┘  └──────┬───────┘
         │                 │
         ↓                 ↓
Layer 2 (Data & Messaging):
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │  OpenSearch  │  │    Kafka     │  │  S3 Storage  │
  │  (cache)     │  │  (queue)     │  │   (files)    │
  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
         │                 │                 │
         └────────┬────────┴─────────────────┘
                  ↓
Layer 3 (Backend Services):
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │ gRPC Server  │  │  Dictionary  │  │  Processor   │
  │  (backend)   │  │    (API)     │  │  (tasks)     │
  └──────┬───────┘  └──────────────┘  └──────────────┘
         │
         ↓
Layer 4 (Proxy & Gateway):
  ┌──────────────┐  ┌──────────────┐
  │ Envoy Proxy  │  │    nginx     │
  │  (gRPC→HTTP) │  │  (gateway)   │
  └──────┬───────┘  └──────┬───────┘
         │                 │
         └────────┬────────┘
                  ↓
Layer 5 (User Interfaces):
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │   ZK UI      │  │   Vue UI     │  │Landing Page  │
  │ (classic)    │  │  (modern)    │  │    (home)    │
  └──────────────┘  └──────────────┘  └──────────────┘
```

**Key dependency rules:**
- UI services wait for backend services to be healthy
- Backend services wait for database and cache to be healthy
- Messaging services (Kafka) wait for coordination (Zookeeper) to be healthy

**Benefits:**
- Services don't start until dependencies are ready
- Reduces connection errors during startup
- Ensures proper initialization order
- Fails fast if critical services don't start

**Troubleshooting:** If a service won't start, check if its dependencies are healthy:
```bash
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
```

See [Troubleshooting Guide](./troubleshooting.md#container-health-checks-failing) for common issues.

#### Health Check Scripts

Two scripts are provided to monitor and verify stack health from the command line.

---

**`health-check.sh`** — point-in-time health report for all containers and HTTP endpoints.

```bash
cd docker-compose/
./health-check.sh
```

The script checks every container across four groups (Infrastructure, Backend Services, Frontend & Gateway, Monitoring & Tooling) and then performs live HTTP requests to key endpoints using each container's internal Docker IP. For each item it reports one of:

- `✅ running · healthy` — container is up and its Docker health check passes
- `⚠️  running · healthcheck starting` — container is up but the health check is still in its grace period (normal in the first 1–2 minutes after startup)
- `❌ running · unhealthy` — container is up but failing its health check
- `❌ <status>` — container is stopped, exited with error, or not found

At the end, a summary shows total passed / failed / warnings. The script exits with code `1` if any checks failed, making it usable in automation.

---

**`full-restart-with-healthcheck.sh`** — performs a full stop → start cycle and confirms the stack is healthy at the end. Useful after configuration changes or to verify a fresh deployment.

```bash
cd docker-compose/
sudo ./full-restart-with-healthcheck.sh
```

The script runs six steps automatically:

1. **Stop** — calls `stop-all.sh` if any stack containers are running
2. **Wait for shutdown** — polls until all containers disappear (timeout: 120 s)
3. **Start** — calls `start-all.sh`
4. **Wait for startup** — polls until all 19 expected long-running containers reach `running` state (timeout: 600 s)
5. **Wait for health checks** — polls until no container is still in the `starting` health state (timeout: 600 s)
6. **Health report** — runs `health-check.sh` and exits with its return code

`sudo` is required only if the user is not in the `docker` group — the script detects this automatically.

---

### Images
Before running containers, images must be downloaded and containers created out of these images.
Image versions used in file *docker-compose.yml*, to be found in DockerHub.
The actual version is defined in file *env_template.env*.

| Image                               | Image Name                                                    |  Tag (Version)                        |
| ----------------------------------- |:-------------------------------------------------------------:|:-------------------------------------:|
| PostgreSQL                          | postgres                                                      | 14.5                                  |
| Main Page / Landing Site            | ghcr.io/adempiere/adempiere-landing-page (1)                  | alpine-1.0.4                          |
| OpenSearch API RESTful              | ghcr.io/adempiere/dictionary-rs                               | 1.6.7                                 |
| ADempiere Report Engine             | ghcr.io/adempiere/adempiere-report-engine-service             | 1.4.2-alpine                          |
| S3 Gateway RESTful API              | ghcr.io/adempiere/s3-gateway-rs                               | 1.2.8                                 |
| S3 Minio Storage                    | quay.io/minio/minio                                           | RELEASE.2025-07-23T15-54-02Z          |
| S3 Minio Client                     | quay.io/minio/mc                                              | RELEASE.2025-07-21T05-28-08Z          |
| DKron Task Scheduler                | dkron/dkron                                                   | 3.2.7                                 |
| Zookeeper for Kafka Brokers         | confluentinc/cp-zookeeper                                     | 7.6.1                                 |
| Kafka Queue Manager                 | confluentinc/cp-kafka                                         | 7.6.1                                 |
| Kafdrop Kafka Cluster Overview      | obsidiandynamics/kafdrop                                      | 4.0.1                                 |
| OpenSearch Search Engine            | opensearchproject/opensearch                                  | 2.15.0                                |
| OpenSearch Dashboards UI            | opensearchproject/opensearch-dashboards                       | 2.15.0                                |
| NGINX UI Gateway                    | nginx                                                         | 1.27.0-alpine3.19                     |
| Envoy gRPC Proxy                    | envoyproxy/envoy                                              | v1.37.0                               |
| Keycloak ID & Access Management     | keycloak/keycloak                                             | 23.0.7                                |
| ADempiere Vue UI                    | ghcr.io/adempiere/adempiere-vue                               | 1.0.0                                  |
| ADempiere Vue Backend (gRPC Server) | ghcr.io/adempiere/adempiere-grpc-server                       | 1.0.0                                  |
| Adempiere ZK UI                     | ghcr.io/adempiere/adempiere-zk                                 | 1.0.0                                  |
| ADempiere Processors gRPC Server    | ghcr.io/adempiere/adempiere-processors-service                 | 1.2.0                                  |

**Notes:**  
- (1) The landing page can be replaced with your own custom image  
- All image versions are defined in `env_template.env` and can be changed as needed  
- **Version updates:** Check image tags regularly for security updates and new features


### Data Persistence

Understanding where the database lives is critical for backups, migrations, and cleanup operations.

#### PostgreSQL — bind-mount volume

The PostgreSQL database is **not stored inside a Docker container or in Docker's internal storage**.  
It uses a Docker named volume backed by a **bind mount** — the volume definition in `docker-compose.yml` points directly to a host directory:

| | Path |
|---|---|
| **Host directory** | `docker-compose/postgresql/postgres_database/` |
| **Container path** | `/var/lib/postgresql/data` |
| **Docker volume name** | `adempiere-ui-gateway.volume_postgres_db` |

The backup directory is mounted the same way:

| | Path |
|---|---|
| **Host directory** | `docker-compose/postgresql/postgres_backups/` |
| **Container path** | `/home/adempiere/postgres_backups` |
| **Docker volume name** | `adempiere-ui-gateway.volume_postgres_backups` |

This is declared in `docker-compose.yml` as:

```yaml
volumes:
  volume_postgres:
    name: ${POSTGRES_VOLUME}
    driver_opts:
      type: none
      o: bind
      device: ${POSTGRES_DB_PATH_ON_HOST}   # resolves to docker-compose/postgresql/postgres_database/
```

#### What this means in practice

- **The database survives container removal.**  
  Running `stop-and-delete-all.sh` removes containers, images, networks, and Docker's named volume definitions — but the host directory and its contents are never touched.  
  The data is always on the host.
- **The database survives `docker volume prune`.**  
  Prune only removes volumes not attached to any running container.  
  Since the bind-mount volume is attached while the stack is up, it is skipped.  
  Even if the stack is down, the host directory remains intact independently of Docker.
- **The database survives `docker image prune -a`.**  
  Images and data storage are completely separate; removing images has no effect on the host directory.
- **Direct host access requires sudo.** PostgreSQL runs inside the container as the `postgres` system user (UID 999 by default), which differs from your host user.  
  Use `sudo ls`, `sudo cp`, etc. to access the directory from the host.
- **Disk space planning must account for database growth.**  
  The database grows on the host partition where `docker-compose/` lives — monitor with `du -sh docker-compose/postgresql/postgres_database/`.
- **Multiple databases can coexist on the host — just swap the directory name.**  
  Because the active database is simply whichever directory is named `postgres_database/`, you can keep several databases side by side on the host:

    ```
    docker-compose/postgresql/  
      postgres_database/         ← currently active (used by the stack)  
      postgres_database_client1/ ← client 1 database (inactive)  
      postgres_database_client2/ ← client 2 database (inactive)
    ```

    To switch databases, stop the stack, rename the directories, and restart:

    ```bash
    sudo mv postgresql/postgres_database          postgresql/postgres_database_client1
    sudo mv postgresql/postgres_database_client2  postgresql/postgres_database
    ./start-all.sh
    ```

    No data is ever moved or copied — only the directory names change.  

- **The host's PostgreSQL engine can access the data directly — even with containers down.**  
  Because the data directory is a standard PostgreSQL data directory on the host filesystem, a locally installed `psql` or `pg_dump` can connect to it directly — even with the Docker stack stopped. This is useful for inspecting or exporting data during maintenance or disaster recovery:

    ```bash
    # Start a temporary postgres instance pointing at the bind-mount directory
    sudo -u postgres pg_ctl -D docker-compose/postgresql/postgres_database start
    sudo -u postgres psql -d adempiere
    ```

  Ensure the PostgreSQL version on the host matches the one used by the container (see `POSTGRES_IMAGE` in `env_template.env`) to avoid data directory incompatibilities.

See [Backup and Restore Guide](./backup-restore.md) for procedures to back up and restore this directory.

---

### User's perspective  
From a user's point of view, the application consists of the following.  
Take note that the ports are defined in file *env_template.env* as external ports and can be changed if needed or desired.  

Services accessible via **path** in the browser through nginx (port 80):

| Path | Service | nginx config file |
|------|---------|-------------------|
| `/` | Landing page | `docker-compose/nginx/api/landing_page.conf` |
| `/webui` | ADempiere ZK UI | `docker-compose/nginx/api/adempiere_zk.conf` |
| `/vue` | ADempiere Vue UI | `docker-compose/nginx/api/adempiere_vue.conf` |

The upstream targets (which container each path points to) are defined in `docker-compose/nginx/upstreams/`.

The path `/api/` also exists in the nginx configuration (`docker-compose/nginx/api/adempiere_backend.conf`) but is **not** a browser URL.   
It is used internally by the Vue Single Page Application (SPA) to send API requests to the Envoy proxy, which transcodes them to gRPC and forwards them to the gRPC server.  
Opening `/api/` in a browser returns 404 because it only responds to specific programmatic API calls with proper headers and request bodies.

Services accessible via **port** directly:

- Postgres database, accessible e.g. by PGAdmin via port **55432**
- OpenSearch Dashboard, accessible via port **5601**
- Access to Kafka Queue via port **29092**
- Kafdrop Kafka Queue Monitor and Administrator, accessible via port **19000**
- DKron browser for monitoring scheduled jobs, accessible via port **8899**
- MinIO Console for monitoring stored objects (files, reports, images), accessible via port **9090**

Beware that **image versions may change ongoing**.



---

[Back to README](../README.md)  | [Previous: System Requirements](./system-requirements.md) | [Next: Profiles](./profiles.md)

