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

### Set correct IP
Get the IP of your machine (here a linux host connected via WiFi):
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
