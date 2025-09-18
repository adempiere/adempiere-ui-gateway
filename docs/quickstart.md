## Quick Start
Make sure you have installed [Git](https://git-scm.com/downloads), [Docker](https://docs.docker.com/engine/install/) and [Java 17](https://adoptium.net/temurin/releases/?version=17).
Clone the repository.
Once the repository is cloned, go to the _Docker Compose_ directory:
```bash
cd docker-compose
```

Start on a console with either command:
```bash
sudo docker compose up
```
Or
```bash
sudo docker compose --profile all up
```
Or
```bash
COMPOSE_PROFILES="all" sudo docker compose up
```
Or
```bash
sudo ./start-all.sh
```

[Back to README](../README.md) | [Next: Architecture](./architecture.md)
