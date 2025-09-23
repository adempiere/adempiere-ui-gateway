# Quick Start
### Prerequisites
Make sure you have installed [Git](https://git-scm.com/downloads), [Docker](https://docs.docker.com/engine/install/) and [Java 17](https://adoptium.net/temurin/releases/?version=17).

### Clone the repository
```bash
git clone https://github.com/adempiere/adempiere-ui-gateway.git
```

### Change to dicrectory
Once the repository is cloned, go to the _Docker Compose_ directory
```bash
cd docker-compose
```

### Set correct IP
Get the IP of your machine (here a linux host conneected via WiFi):
```bash
ip addr show | grep wlp3s0
```

Replace on file env_template.env the value of variable **HOST_IP** with your host IP:
```bash
nano env_template.env
```

### Start Services
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

### Check Application
Start on a browser: ```hppt://<HOST_IP>/webui``` or ```hppt://<HOST_IP>/vue```

[Back to README](../README.md) | [Next: Architecture](./architecture.md)
