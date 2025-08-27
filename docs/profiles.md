
## Profiles
This applications exploits the Docker Compose Profiles.

It basically defines a group of services that can be started or stopped togheter; this group is named a "profile".
In the file docker-compose.yml the profiles are defined for every service; this can be changed anytime accordingly to the needs.

By calling *docker compose up* or *./start-all.sh* plus a parameter, the parameter is interpreted as the profile to be used.

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
COMPOSE_PROFILES="auth" docker compose up
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
COMPOSE_PROFILES="cache" docker compose up
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
COMPOSE_PROFILES="report" docker compose up
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
COMPOSE_PROFILES="scheduler" docker compose up
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
COMPOSE_PROFILES="storage" docker compose up
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
COMPOSE_PROFILES="vue" docker compose up
```


#### Services activated with _ADempiere-Zk UI_ Profile
 - postgres-service
 - zk
 - ui-gateway

![ADempiere Zk UI Architecture](architecture/architecture-zk.png)

Start with:
```bash
COMPOSE_PROFILES="zk" docker compose up
```


#### Multiple profiles
For example `report`, `vue` and `zk` combined profiles, activates the services of:

 - postgres-service
 - adempiere-grpc-server
 - adempiere-report-engine
 - grpc-proxy
 - vue-ui
 - zk
 - ui-gateway

Start with:
```bash
COMPOSE_PROFILES="report,vue,zk" docker compose up
```

[Back to README](../README.md) | [Previous: Architecture](./architecture.md)  | [Next: Installation](./installation.md)
