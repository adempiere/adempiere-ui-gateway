# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **ADempiere UI Gateway** - a Docker Compose-based stack for running ADempiere ERP with multiple UI options (ZK and Vue), integrated services, and a complete microservices architecture. The stack uses nginx as a reverse proxy/API gateway to route requests to various backend services.

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
- Keycloak (authentication - optional)
- DKron (job scheduling)

## Architecture

The stack uses Docker Compose profiles for flexible service composition:

1. **Single docker-compose.yml**: All services defined in one file (`docker-compose/docker-compose.yml`)
2. **Profile-Based Activation**: Each service is tagged with profiles (e.g., `''`, `all`, `auth`, `cache`, `develop`, `storage`, `vue`, `zk`)
3. **Stack Modes**: The `start-all.sh` script activates appropriate profiles to start different service combinations:
   - **default/standard** (profile: `''` - empty): Core ADempiere services + PostgreSQL + ZK UI + gRPC + nginx
   - **develop**: Adds monitoring tools and exposes additional ports
   - **auth**: Includes Keycloak for SSO
   - **cache**: Minimal stack for OpenSearch dictionary testing
   - **storage**: S3 storage + minimal services
   - **vue**: Vue UI + minimal backend services
4. **UI Gateway**: nginx acts as the single entry point, routing to ZK UI (`/webui`), Vue UI (`/vue`), gRPC services (`/api`), and monitoring tools

**Network Architecture:**
- All containers run on a custom bridge network (default: `192.168.100.0/24`)
- nginx reverse proxy handles all external requests on port 80
- Internal services communicate via container hostnames
- External ports are exposed only when needed (e.g., Postgres on 55432 for development)

## Essential Commands

### Starting the Stack

All commands must be run from the `docker-compose/` directory:

```bash
cd docker-compose/
```

**Standard/Production stack:**
```bash
./start-all.sh -d default
# or simply:
./start-all.sh
```

**Development stack** (exposes additional ports, includes monitoring):
```bash
./start-all.sh -d develop
```

**Vue-only stack** (minimal services for Vue UI):
```bash
./start-all.sh -d vue
```

**Cache stack** (dictionary cache testing):
```bash
./start-all.sh -d cache
```

**Auth stack** (with Keycloak SSO):
```bash
./start-all.sh -d auth
```

**Storage stack** (S3 storage testing):
```bash
./start-all.sh -d storage
```

### Stopping the Stack

```bash
cd docker-compose/
./stop-all.sh
```

This stops all containers and deletes the assembled `docker-compose.yml` file.

### Complete Cleanup (Dangerous!)

```bash
cd docker-compose/
./stop-and-delete-all.sh
```

⚠️ **WARNING**: This deletes ALL Docker containers, images, networks, cache, and volumes on the system. Only the persistent database directory (`postgresql/postgres_database`) is preserved.

### Service Management

```bash
# View running services
docker compose ps -a

# Restart a single service
docker compose restart adempiere-site

# Stop a service
docker compose stop adempiere-zk

# View logs
docker container logs adempiere-ui-gateway.postgres
docker container logs adempiere-ui-gateway.zk

# Execute commands in container
docker container exec -it adempiere-ui-gateway.postgres bash
```

### Database Operations

**Create backup:**
```bash
cd postgresql/postgres_backups
docker exec -i adempiere-ui-gateway.postgresql pg_dump --no-owner -h localhost -U postgres adempiere > adempiere-$(date '+%Y-%m-%d').backup
```

**Restore database:**
1. Place backup file as `seed.backup` in `postgresql/postgres_backups/`
2. Ensure `postgresql/postgres_database/` is empty (delete contents if needed)
3. Start the stack - it will automatically restore from the seed file

**Delete database to force restore:**
```bash
sudo rm -rf postgresql/postgres_database/*
```

### Debugging

```bash
# View resolved configuration (merges env_template.env with docker-compose files)
cp env_template.env .env
docker compose convert

# Inspect container configuration
docker container inspect adempiere-ui-gateway.postgres
```

## Configuration

**Primary configuration file:** `docker-compose/env_template.env`

Key variables to customize:
- `COMPOSE_PROJECT_NAME` - project/client name (derives all container names)
- `HOST_IP` - IP or domain where stack is accessible (e.g., `erp-adempiere.westfalia-it.com`)
- `POSTGRES_IMAGE` - PostgreSQL version
- `ADEMPIERE_GITHUB_VERSION` - ADempiere database version for initial seed
- Port mappings for external access (e.g., `POSTGRES_EXTERNAL_PORT=55432`)

**After modifying `env_template.env`:**
The `start-all.sh` script automatically copies it to `.env` before running docker compose.

## Working Directory Structure

```
docker-compose/
├── env_template.env          # Main configuration (copy to .env)
├── docker-compose.yml        # All service definitions with profiles
├── start-all.sh              # Start stack script (activates profiles)
├── stop-all.sh               # Stop stack script
├── stop-and-delete-all.sh    # Complete cleanup script
├── postgresql/
│   ├── postgres_database/    # Persistent DB storage (mounted volume)
│   ├── postgres_backups/     # Backup/restore files
│   ├── persistent_files/     # ZK container shared files
│   ├── postgres.Dockerfile   # Custom Postgres image
│   └── initdb.sh             # DB initialization script
├── nginx/
│   ├── nginx.conf            # Main nginx config
│   ├── api_gateway.conf      # API gateway routing
│   ├── upstreams/            # Backend service definitions
│   ├── api/                  # API endpoint configs
│   └── gateway/              # Gateway-specific configs
└── opensearch/
    └── setup_opensearch.sh   # OpenSearch initialization
```

## Important Implementation Details

### Stack Assembly Logic

The `start-all.sh` script uses arrays to define which service files belong to each stack mode:
- `AUTH_array` - services for authentication stack
- `CACHE_array` - services for cache testing
- `DEVELOP_array` - services for development (includes extra ports, monitoring)
- `STANDARD_array` - production-ready services (customized for this deployment)
- `STORAGE_array` - S3 storage services
- `VUE_array` - minimal Vue-only stack

Services are assembled in a specific order and written to `docker-compose.yml`.

### Database Initialization

The `postgresql/initdb.sh` script runs automatically on first database creation:
1. Checks if database `adempiere` exists
2. If not, checks for `seed.backup` file in backups directory
3. If no seed file, downloads latest ADempiere seed from GitHub
4. Creates database and restores from seed
5. **Will NOT run** if database already exists or if DB directory has contents

### Service Naming Convention

Docker compose service files follow this pattern:
- `##[a-z]-<service>_service_<variant>.yml`
- Number prefix (`01`, `17`, etc.) determines assembly order
- Letter suffix (`a`, `b`, `c`) indicates variants (e.g., with/without ports)
- Example: `01a-postgres_service_with_ports.yml` vs `01b-postgres_service_without_ports.yml`

### Custom Modifications

The STANDARD_array has been customized for this installation:
- Uses Postgres with ports exposed (`01a` instead of `01b`)
- Includes Kafdrop for Kafka monitoring (`13b` instead of `13a`)
- Includes OpenSearch dashboards
- Includes electronic invoicing service for El Salvador (`92-svfe-api-firmador.yml`)

## Access Points

When stack is running (default ports from `env_template.env`):
- **Home/Landing page**: `http://<HOST_IP>/` (port 80)
- **ZK UI**: `http://<HOST_IP>/webui`
- **Vue UI**: `http://<HOST_IP>/vue`
- **API (gRPC transcoding)**: `http://<HOST_IP>/api/`
- **PostgreSQL**: `<HOST_IP>:55432` (via PGAdmin or other client)
- **OpenSearch Dashboard**: `http://<HOST_IP>:5601`
- **Kafdrop (Kafka monitor)**: `http://<HOST_IP>:19000`
- **DKron (scheduler monitor)**: `http://<HOST_IP>:8899`
- **MinIO Console (S3 browser)**: `http://<HOST_IP>:9090`

## Security Considerations

Docker bypasses host firewall rules by manipulating iptables directly. Exposed ports are accessible regardless of UFW/firewall settings. **Always use an external firewall** (cloud provider firewall, hardware firewall) to restrict access to the host. Never expose the host directly to the internet without proper firewall protection upstream.

## Branch Information

- **Main branch**: `main` - use for pull requests
- **Current working branch**: `feature/SHW_General`
