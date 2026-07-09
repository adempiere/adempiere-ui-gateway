
## Profiles

### Profile-Based Activation Pattern

The stack uses a **profile-based activation** model to allow flexible service composition from a single `docker-compose.yml` file:

- Every service definition is tagged with one or more profile names (e.g. `all`, `auth`, `cache`, `storage`, `vue`, `zk`).
- Only services whose profile matches the activated profile are started — all others are ignored.
- This design means you can run a minimal Vue-only stack, a full production stack, or anything in between — without modifying the service definitions.

This application exploits the [Docker Compose Profiles](https://docs.docker.com/compose/how-tos/profiles/).

### Using Profiles with the Scripts

All three management scripts accept an optional profile argument (default: `all`):

```bash
./start-all.sh [profile]
./health-check.sh [profile]
./full-restart-with-healthcheck.sh [profile]
```

**`start-all.sh`** — starts only the services belonging to the given profile:
```bash
./start-all.sh          # starts all services (default)
./start-all.sh vue      # starts only the vue-profile services
./start-all.sh zk       # starts only the zk-profile services
```

**`health-check.sh`** — checks only the containers belonging to the given profile:
```bash
./health-check.sh       # checks all containers that exist in Docker
./health-check.sh vue   # checks only vue-profile containers (regardless of what else is running)
./health-check.sh zk    # checks only zk-profile containers
```
Containers that do not exist (not started) or are excluded by the profile are silently skipped — they do not count as failures.

**`full-restart-with-healthcheck.sh`** — stops everything, restarts with the given profile, waits for the stack to be ready, and runs the health check:
```bash
./full-restart-with-healthcheck.sh        # restart with all services
./full-restart-with-healthcheck.sh vue    # restart with only vue-profile services
./full-restart-with-healthcheck.sh zk     # restart with only zk-profile services
```
The script discovers which containers were actually started after `start-all.sh` runs, so the wait and health-check steps automatically cover exactly the services that belong to the active profile.

---

| Profile | Key | Description |
|---------|-----|-------------|
| [Default / Standard](#services-activated-with-defaultstandard-profile-no-parameter-or-empty-string) | _(no parameter)_ | Production-ready core stack (ZK + Vue + gRPC) |
| [Authentication](#services-activated-with-authentication-profile) | `auth` | Core stack with Keycloak identity provider |
| [Dictionary Cache](#services-activated-with-dictionary-cache-profile) | `cache` | Adds Kafka + OpenSearch + dictionary-rs caching layer |
| [Dictionary Report Engine](#services-activated-with-dictionary-report-engine-profile) | `report` | Adds report engine service |
| [Processor Scheduler](#services-activated-with-processor-scheduler-profile) | `scheduler` | Adds ADempiere processor and Dkron scheduler |
| [S3 Storage](#services-activated-with-s3-storage-profile) | `storage` | Adds MinIO S3 storage and gateway |
| [ADempiere-Vue UI](#services-activated-with-adempiere-vue-ui-profile) | `vue` | Minimal stack: Vue UI + gRPC only |
| [ADempiere-Zk UI](#services-activated-with-adempiere-zk-ui-profile) | `zk` | Minimal stack: ZK UI only |
| [All](#services-activated-with-all-profile) | `all` | Complete stack with all available services |
| [Multiple profiles](#multiple-profiles) | combined | Combining multiple profile keys |

#### Services activated with _Default/Standard_ Profile (No parameter or empty string)
This is the **production-ready stack** with all core ADempiere services. This profile runs when you execute `./start-all.sh` without any parameter.

 - postgres-service
 - adempiere-site
 - adempiere-zk
 - vue-ui
 - vue-grpc-server
 - adempiere-grpc-server
 - grpc-proxy
 - ui-gateway

![ADempiere Standard Architecture](architecture/architecture-all.png)

Start with:
```bash
./start-all.sh
```

**Note:** This is the recommended stack for production deployments.


#### Services activated with _Authentication_ Profile
 - postgres-service
 - adempiere-zk
 - keycloak
 - adempiere-grpc-server
 - grpc-proxy
 - vue-ui
 - ui-gateway

![ADempiere Authentication Architecture](architecture/architecture-auth.png)

Start with:
```bash
./start-all.sh auth
```


#### Services activated with _Dictionary Cache_ Profile
 - postgres-service
 - adempiere-grpc-server
 - grpc-proxy
 - zookeeper
 - kafka
 - opensearch-node
 - opensearch-setup
 - dictionary-rs
 - vue-ui
 - ui-gateway

![Dictionary Cache Architecture](architecture/architecture-cache.png)

Start with:
```bash
./start-all.sh cache
```


#### Services activated with _Dictionary Report Engine_ Profile
 - postgres-service
 - adempiere-grpc-server
 - adempiere-report-engine
 - grpc-proxy
 - vue-ui
 - ui-gateway

![ADempiere Report Engine Architecture](architecture/architecture-report.png)

Start with:
```bash
./start-all.sh report
```


#### Services activated with _Processor Scheduler_ Profile
 - postgres-service
 - adempiere-zk
 - adempiere-processor
 - dkron-scheduler
 - adempiere-grpc-server
 - grpc-proxy
 - vue-ui
 - ui-gateway

![ADempiere Processor Scheduler Architecture](architecture/architecture-scheduler.png)

Start with:
```bash
./start-all.sh scheduler
```


#### Services activated with _S3 Storage_ Profile
 - postgres-service
 - s3-storage
 - s3-client
 - s3-gateway-rs
 - adempiere-grpc-server
 - grpc-proxy
 - vue-ui
 - ui-gateway

![ADempiere S3 Storage Architecture](architecture/architecture-storage.png)

Start with:
```bash
./start-all.sh storage
```


#### Services activated with _ADempiere-Vue UI_ Profile
 - postgres-service
 - adempiere-grpc-server
 - grpc-proxy
 - vue-ui
 - ui-gateway

![ADempiere Vue UI Architecture](architecture/architecture-vue.png)

Start with:
```bash
./start-all.sh vue
```


#### Services activated with _ADempiere-Zk UI_ Profile
 - postgres-service
 - zk
 - ui-gateway

![ADempiere Zk UI Architecture](architecture/architecture-zk.png)

Start with:
```bash
./start-all.sh zk
```


#### Services activated with _All_ Profile
The **all** profile activates the complete stack with ALL available services, including monitoring tools and optional components.

Start with:
```bash
./start-all.sh all
```
Or equivalently (since `all` is the default):
```bash
./start-all.sh
```


#### Multiple profiles
Profiles can be **combined** to activate services from different profiles. For example `report`, `vue` and `zk` combined profiles, activates the services of:

 - postgresql-service
 - adempiere-grpc-server
 - adempiere-report-engine
 - grpc-proxy
 - vue-ui
 - adempiere-zk
 - ui-gateway

Pass the profiles as a **single, comma-separated argument** (no spaces). Start the combined stack with the script:
```bash
./start-all.sh report,vue,zk
```

Or invoke Docker Compose directly:
```bash
COMPOSE_PROFILES="report,vue,zk" docker compose up -d
```

> **Important:** the profiles must be comma-separated in a single argument. A space-separated form such as `./start-all.sh report vue zk` does **not** work — `start-all.sh` only reads the first argument, so only `report` would be activated (and `COMPOSE_PROFILES` itself is comma-separated, never space-separated).

**Note:** The default profile (empty string `''`) is always included unless you explicitly specify other profiles.


---

[Back to README](../README.md) | [Previous: Architecture](./architecture.md)  | [Next: Installation](./installation.md)

