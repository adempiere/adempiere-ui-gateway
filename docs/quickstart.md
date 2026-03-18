# Quick Start

> **💡 Important: No Java Installation Required**
>
> You do NOT need to install Java, JDK, or any Java tools on your computer.
> Java runs inside the Docker containers and is already included in the images.
> This is one of the main benefits of using Docker!

### What You Need

✓ Docker (20.10 or later)
✓ Docker Compose (v2.16.0 or later)
✓ Git
✓ Python 3.10 or later (required for the `generate_env.py` script)

### What You DON'T Need

✗ Java/JDK (runs inside containers)
✗ Application servers (runs inside containers)
✗ PostgreSQL (runs inside containers)
✗ nginx (runs inside containers)

**Everything except Docker, Docker Compose, Git, and Python runs inside containers!**

**Security benefit:** This isolation minimizes your host's attack surface. Software running only in containers cannot directly compromise your host system, even if vulnerabilities exist.

### Clone the Repository

```bash
git clone https://github.com/adempiere/adempiere-ui-gateway.git
cd adempiere-ui-gateway
cd docker-compose
```

### Set Host-Specific Values

You have two ways to set host-specific values (e.g. IP address, external ports, credentials):

- **Option A — recommended:** create a local `override.env` so you don't modify the versioned template.

  1. Copy the provided example template:
     ```bash
     cp override_template.env override.env
     ```
  2. Edit only the variables you want to change (e.g. `HOST_IP`, `POSTGRES_EXTERNAL_PORT`):
     ```bash
     nano override.env
     ```
  - `override.env` is git-ignored — your local values will never be accidentally committed.
  - `start-all.sh` detects `override.env` and automatically generates a merged `.env` from it.

- **Option B — less recommended:** directly edit `env_template.env`. Be careful not to commit sensitive values.
  ```bash
  nano env_template.env
  ```

To find your host IP (example for Wi-Fi interface `wlp3s0`):
```bash
ip addr show | grep wlp3s0
```

**Notes on variable resolution:**  
- `generate_env.py` resolves `${VAR}` and `$VAR` references recursively. For example: if `override.env` sets `HOST_IP=192.0.2.10`, all template variables that reference `${HOST_IP}` will be expanded accordingly.  
- You can also call the generator manually:  
  ```bash
  ./generate-env.sh override.env .env
  # or directly:
  python3 generate_env.py env_template.env override.env .env
  ```

### Start the Stack

```bash
./start-all.sh
```

This script automatically generates `.env` (merging `env_template.env` with `override.env` if present), then starts all services. See [Profiles](./profiles.md) for starting specific service combinations.

### Check the Application

Open in a browser:

| URL | Service |
|-----|---------|
| `http://<HOST_IP>/` | Landing page |
| `http://<HOST_IP>/webui` | ZK UI (classic) |
| `http://<HOST_IP>/vue` | Vue UI (modern) |

Replace `<HOST_IP>` with the value you set for `HOST_IP` in your configuration.

---

### Frequently Asked Questions

**Q: Do I need to install Java on my computer?**

A: **No!** Java runs inside the Docker containers. The Docker images already contain Java — you don't need to install it on your host machine. You only need Docker, Docker Compose, Git, and Python.

**Security benefit:** Keeping Java only in containers (not on your host) reduces your attack surface. If Java were installed on the host, it could potentially be exploited to execute undesired programs. Docker's isolation protects your host system.

**Q: Why do I see Java version numbers in the documentation?**

A: Those refer to the Java version running inside the containers, not on your host.

**Q: What if I want to compile ADempiere source code?**

A: Then you would need Java on your host for development. But for simply running this Docker stack with pre-built images, you don't need Java installed locally.

**Q: Do I need to install PostgreSQL, nginx, or other services?**

A: **No!** All services run inside Docker containers. You only need Docker itself.

---

### Key Configuration Variables

The primary configuration file is `docker-compose/env_template.env`. Edit it to customise your deployment, or use `override.env` for host-specific values. `start-all.sh` automatically generates `.env` from them — do not create `.env` manually.

| Variable | Purpose | Example |
|----------|---------|---------|
| `COMPOSE_PROJECT_NAME` | Project/client name; all container names are derived from this | `adempiere-ui-gateway` |
| `HOST_IP` | IP address or domain where the stack is accessible | `erp-adempiere.example.com` |
| `POSTGRES_IMAGE` | PostgreSQL Docker image version | `postgres:14.5` |
| `ADEMPIERE_GITHUB_VERSION` | ADempiere database seed version downloaded on first start | `3.9.4` |
| `POSTGRES_EXTERNAL_PORT` | External port for PostgreSQL access (develop mode) | `55432` |
| `NETWORK_SUBNET` | Docker bridge network subnet | `192.168.100.0/24` |

For the complete variable reference, open `docker-compose/env_template.env` — it contains inline comments for every variable.

---

[Back to README](../README.md) | [Next: System Requirements](./system-requirements.md)
