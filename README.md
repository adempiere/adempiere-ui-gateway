# adempiere-ui-gateway
A comprehensive Docker-based deployment system for ADempiere ERP with modular service profiles.

### Application Running
![ADempiere Vue](docs/adempiere_ui_gateway_Vue.gif)

![ADempiere ZK](docs/adempiere_ui_gateway_ZK.gif)
This project implements a Stack for ADempiere UI.

### General Explanation
This application consists of several containers that interact with each other to deliver the functionality of ADempiere.

The application downloads the required images for each container, runs the configured containers and restores the database if needed on your local machine **just by calling a script**!

It basically consists of a *docker compose* project that defines in a *docker-compose.yml* file all services needed to run ADempiere, Postgres, ZK, Vue and other services, all configurable with docker compose profiles.

A configuration file (_env_template.env_) defines all modifiable values (e.g. release versions, ports, container names etc.) to be used in the *docker-compose.yml* file; also a Docker Compose Profile defines the stack, i.e. the services to be used. Any combination of the services offered is possible with the help of Docker Compose "profiles".

When executed with the shell script _start-all.sh_, the script first generates the runtime configuration file _.env_ from _env_template.env_ (and _override.env_ if present), then starts the *docker compose* project with the selected profile. Only the services matching the chosen profile are started as Docker containers; together they comprise the application stack.

Due to the technology used, it is highly recommended to have a good knowledge of [Docker](https://docs.docker.com/get-started/) and [Docker Compose](https://docs.docker.com/compose/) to understand, customise, and administer this application properly. It is also useful to know how each container works.

### Benefits of the Application
- In its simplest form, it can be used as a demo of the latest -or any desired- ADempiere version.
- No big installation hassle for getting it running: just execute the shell script **start-all.sh** .
- It can run on different hosts just by changing  
    - the target IP to the one of the host or  
    - the client name (this is optional)
- Fully configurable: all stack parameters — hostnames, ports, image versions, database settings, and more — are defined in a single configuration file, **env_template.env**.   
    Machine-specific overrides can be placed in **override.env** without touching the versioned template.
- Single containers or images can be updated and/or replaced easily, making deployments and tests speedy.
- Separation of concerns: every service implements one and only one solution.
- Container timezone must be explicitly set (`GENERIC_TIMEZONE`, `GENERIC_CENTRAL_STANDARD_TIME` in `override.env`) — the stack refuses to start with defaults — so timestamps are always correct and predictable regardless of where it runs.
- Ideal for testing situations due to its ease of configuration and execution.
- No need of deep knowledge of ADempiere Installation, Application Server Installation, Docker, Images or Postgres just to get the stack running.
- Every container, image and object is unique, derived from a configuration file.
- New services can be easily added.


### Current Limitation — HTTP Only

> ⚠️ **The stack currently runs on HTTP (port 80) only.** Native HTTPS support is not yet built in — the community is actively working on it.
>
> In the meantime, two workarounds are available:
> - **Let's Encrypt + Certbot** — obtain a free certificate and mount it into the nginx container
> - **Cloudflare Proxy** — route traffic through Cloudflare for free HTTPS termination without touching the server
>
> See [Security — HTTPS/SSL Configuration](docs/security.md#httpsssl-configuration) for step-by-step instructions.

### Table of Contents
Please follow the links for detailed information.

- [Quick Start](docs/quickstart.md)
- [System Requirements](docs/system-requirements.md)
- [Architecture](docs/architecture.md)
- [Profiles](docs/profiles.md)
- [Installation](docs/installation.md)
- [Display Services](docs/services.md)
- [Security Information](docs/security.md)
- [Backup and Restore](docs/backup-restore.md)
- [Debugging](docs/debugging.md)
- [Debugging Vue Frontend](docs/debugging-vue-frontend.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Additional Info](docs/additional_info.md)
- [License](./LICENSE)

- See installation prerequisites in [Installation](docs/installation.md) (Python 3.10+ required for the generator script).
