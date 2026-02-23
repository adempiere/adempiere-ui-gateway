# Quick Start

> **💡 Important: No Java Installation Required**
>
> You do NOT need to install Java, JDK, or any Java tools on your computer.
> Java runs inside the Docker containers and is already included in the images.
> This is one of the main benefits of using Docker!

### Prerequisites
Make sure you have installed [Git](https://git-scm.com/downloads) and [Docker](https://docs.docker.com/engine/install/).

### What You Need

✓ Docker (20.10 or later)
✓ Docker Compose (v2.16.0 or later)
✓ Git
✓ Python

### What You DON'T Need

✗ Java/JDK (runs inside containers)
✗ Application servers (runs inside containers)
✗ PostgreSQL (runs inside containers)
✗ nginx (runs inside containers)

**Everything except Docker, Docker Compose, and Git runs inside containers!**

**Security benefit:** This isolation minimizes your host's attack surface. Software running only in containers cannot directly compromise your host system, even if vulnerabilities exist.

### Clone the repository
```bash
git clone https://github.com/adempiere/adempiere-ui-gateway.git
```

### Change to directory
Once the repository is cloned, go to the _Docker Compose_ directory
```bash
cd docker-compose
```

### Set values
Get the IP of your machine (here a linux host connected via WiFi):
```bash
ip addr show | grep wlp3s0
```

Replace on file `override.env` the value of variable **HOST_IP** with your host IP:
```bash
cp override_template.env override.env
```
### Set values
You have two recommended ways to set host-specific values (e.g. IP, external ports, credentials):

- Option A (recommended): create or edit a local override file so you don't modify the template shipped in the repo.
	1. Copy the provided example template:
	```bash
	cp docker-compose/override_template.env docker-compose/override.env
	```
	2. Edit only the variables you want to change (example: `HOST_IP`, `POSTGRES_EXTERNAL_PORT`):
	```bash
	nano docker-compose/override.env
	```

- Option B (less recommended): directly edit `docker-compose/env_template.env`. Be careful not to commit sensitive values.
	- To find your host IP (example for Wi‑Fi interface `wlp3s0`):
	```bash
	ip addr show | grep wlp3s0
	```
	- Then open the template and update `HOST_IP`:
	```bash
	nano docker-compose/env_template.env
	```

Notes:
- Use `override.env` to keep local changes out of git (the repo already ignores `docker-compose/override.env`).
- Variable names must match exactly those used in `env_template.env` (the generator resolves references like `${VAR}` recursively).

Generate `.env` using the provided wrapper (requires Python 3.10+):
```bash
cd docker-compose
./generate-env.sh override.env .env
# or directly with python:
python3 generate_env.py env_template.env override.env .env
```


### Generate .env (optional — recommended if you want to override values)
You can create a small `override.env` with only the variables you want to change and generate a merged `.env` that preserves template order and comments.

Example `override.env` (only override what you need):
```
### Generate .env (optional — recommended when using overrides)
If you created `docker-compose/override.env` the repository includes a generator that merges it with the template and resolves variable references.

Example `docker-compose/override.env` (only the variables you want to change):
```
# local overrides
HOST_IP=192.0.2.10
POSTGRES_EXTERNAL_PORT=55433
OPENSEARCH_PORT=9300
```

Generate the merged `.env` (from repo root):
```bash
cd docker-compose

# preferred wrapper (calls the Python generator and validates):
./generate-env.sh override.env .env

# or call the script directly:
python3 generate_env.py env_template.env override.env .env
```

Behavior notes:
- `generate_env.py` resolves `${VAR}` and `$VAR` recursively (up to a convergence limit). If you set `KAFKA_BROKER_EXTERNAL_PORT=${KAFKA_BROKER_PORT}` in `override.env` and `KAFKA_BROKER_PORT=29092`, the final `.env` will contain `KAFKA_BROKER_EXTERNAL_PORT=29092` and any template entries that reference it (e.g. `KAFKA_EXTERNAL_BROKERCONNECT="${HOST_IP}:${KAFKA_BROKER_EXTERNAL_PORT}"`) will be expanded accordingly.
- `start-all.sh` will: use `docker-compose/override.env` (if present) to generate `.env`; if `.env` already exists and no `override.env` is present, it will keep the existing `.env` and will not overwrite it.

Start the stack:
```bash
./start-all.sh
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
Start on a browser: ```http://<HOST_IP>/webui``` or ```http://<HOST_IP>/vue```

---

### Frequently Asked Questions

**Q: Do I need to install Java on my computer?**

A: **No!** Java runs inside the Docker containers. The Docker images already contain Java - you don't need to install it on your host machine. You only need Docker, Docker Compose, and Git.

**Security benefit:** Keeping Java only in containers (not on your host) reduces your attack surface. If Java were installed on the host, it could potentially be exploited to execute undesired programs. Docker's isolation protects your host system.

**Q: Why do I see Java version numbers in the documentation?**

A: Those refer to the Java version running INSIDE the containers, not on your host.

**Q: What if I want to compile ADempiere source code?**

A: Then you would need Java on your host for development. But for simply running this Docker stack with pre-built images, you don't need Java installed locally.

**Q: Do I need to install PostgreSQL, nginx, or other services?**

A: **No!** All services run inside Docker containers. You only need Docker itself.

---

[Back to README](../README.md) | [Next: System Requirements](./system-requirements.md)
