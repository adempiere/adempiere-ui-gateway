## Quick Start
Make sure you have installed Git, Docker and Java 17.
Clone the repsoitory.
Once the repository is cloned, go to the DockerCompose directory:
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
