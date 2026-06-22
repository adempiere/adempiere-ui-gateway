# Remote Access via SSH Tunnel

## Index

| Section | Description |
|---------|-------------|
| [Preferred method for cloud deployments](#preferred-method-for-cloud-deployments) | Why SSH tunneling is the secure approach |
| [How to open a tunnel](#how-to-open-a-tunnel) | Setup and usage of `ssh -L` port forwarding |
| [Services reachable via SSH tunnel](#services-reachable-via-ssh-tunnel) | Port reference table for all internal services |
| [Practical examples per service](#practical-examples-per-service) | PostgreSQL, Kafdrop, OpenSearch, Dkron, dictionary-rs, MinIO, Keycloak |

---

## Preferred method for cloud deployments

When the ADempiere UI Gateway stack runs on a cloud server, most internal services (PostgreSQL, Kafdrop, OpenSearch Dashboards, Dkron, MinIO, Keycloak) are **not exposed in the firewall**.  
Only ports 80 (nginx), 443 (HTTPS), and the SSH port are open to the internet.

**Opening additional firewall ports to access these services is strongly discouraged.**  
Docker bypasses host-level firewalls (UFW, iptables) by inserting its own rules, meaning a port opened in Docker is reachable from the internet even if you think the firewall blocks it.  
An exposed PostgreSQL port, for example, can be exploited via the built-in `COPY FROM PROGRAM` feature to execute arbitrary commands inside the container.

The correct and secure alternative is an **SSH tunnel**: the service traffic travels encrypted through the existing SSH connection. No firewall changes are needed.

---

## How to open a tunnel

The `-L` option of SSH creates the tunnel. Its syntax is:

```
-L <local-port>:127.0.0.1:<remote-port>
```

- **`<local-port>`** — the port you open in your browser on your local machine (e.g. `http://localhost:19000`)  
- **`127.0.0.1`** — the address on the *remote server* where the service listens (always localhost there, since the service is not exposed publicly)  
- **`<remote-port>`** — the port the service runs on at the remote server

In practice both numbers are the same (e.g. `19000:127.0.0.1:19000`), because we use the same port number locally as on the server for clarity.

**Step 1 — Local machine:** Open a terminal and start the tunnel (replace both port numbers with the service port from the table below):

```bash
ssh -i <path-to-ssh-key> \
    -p <ssh-port> \
    -L <local-port>:127.0.0.1:<remote-port> \
    <user>@<server-ip> \
    -N
```

Keep this terminal open — the tunnel stays active as long as the command runs.

**Step 2 — Local machine:** Open your browser at `http://localhost:<local-port>`.

**Step 3 — Local machine:** When done, press `Ctrl+C` in the tunnel terminal to close it.

Multiple ports can be tunneled in a single SSH connection:

```bash
ssh -i <path-to-ssh-key> \
    -p <ssh-port> \
    -L 19000:127.0.0.1:19000 \
    -L 5601:127.0.0.1:5601 \
    -L 8899:127.0.0.1:8899 \
    -L 9090:127.0.0.1:9090 \
    <user>@<server-ip> \
    -N
```

---

## Services reachable via SSH tunnel

The remote ports below are the external ports each service publishes on the server.  
They are defined in `env_template.env` (variables named `*_EXTERNAL_PORT`) and can be overridden in `override.env`.  

| Service | Remote port | Open in browser |
|---------|-------------|-----------------|
| Kafdrop (Kafka UI) | 19000 | `http://localhost:19000` |
| OpenSearch Dashboards | 5601 | `http://localhost:5601` |
| Dkron web UI | 8899 | `http://localhost:8899/ui` |
| MinIO console | 9090 | `http://localhost:9090` |
| Keycloak | 3333 | `http://localhost:3333` |
| PostgreSQL (PGAdmin) | 5432 | — (database client) |

**nginx (ports 80/443): no tunnel needed** — it is intentionally public and is the main entry point for the Vue UI, ZK, and the API gateway.

**Kafka broker (port 29092): tunneling is unreliable.**  
- Kafka advertises its own address to clients during the initial handshake.  
- If you tunnel port 29092, Kafka may redirect your client to its internal Docker network address, which is not reachable from outside.  
- Use Kafdrop via tunnel instead.

**dictionary-rs** does not need to be accessed directly — its endpoints are proxied by nginx at `http://<server-ip>/api/`.

---

## Practical examples per service

---

### PostgreSQL — database access via PGAdmin

PGAdmin supports SSH tunneling natively — no command-line tunnel needed.

In PGAdmin, open the **SSH Tunnel** tab when creating a server connection:

| Field | Value |
|-------|-------|
| Use SSH tunneling | Yes |
| Tunnel host | `<server-ip>` |
| Tunnel port | `<ssh-port>` |
| Username | `<ssh-user>` |
| Authentication | Identity file |
| Identity file | `<path-to-ssh-key>` |

Then on the **Connection** tab:

| Field | Value |
|-------|-------|
| Host name / address | `127.0.0.1` |
| Port | `5432` |
| Maintenance database | `adempiere` |
| Username | `postgres` |
| Password | (PostgreSQL superuser password from `override.env`) |

For read/write access without superuser privileges, connect as user `adempiere` to database `adempiere` instead.

**Command-line alternative:**

**Step 1 — Local machine:**
```bash
ssh -i <path-to-ssh-key> \
    -p <ssh-port> \
    -L 15432:127.0.0.1:5432 \
    <user>@<server-ip> \
    -N
```
Port `15432` is used locally to avoid conflicts with a local PostgreSQL instance.

**Step 2 — Local machine:**
```bash
psql -h 127.0.0.1 -p 15432 -U postgres -d adempiere
```

---

### Kafdrop — Kafka topic browser (port 19000)

**Local machine:** Open tunnel on port 19000, then open `http://localhost:19000`.

**List all topics:**  
- The main page shows every Kafka topic with its partition count and message count.  
- For a healthy ADempiere stack you should see: `browser`, `form`, `menu_item`, `menu_tree`, `process`, `role`, `window`.

**Inspect messages in a topic:**  
- Click on a topic name → **View Messages** → set offset and count → **View Messages**.  
- Useful for verifying that `Export Application Dictionary` actually published data.

**Delete a topic:**  
- Click on a topic name → **Delete Topic** → confirm.  
- Use with care — deleting a topic that dictionary-rs is subscribed to will cause it to lose its messages.  
- A new Export Application Dictionary run will be needed afterwards.

---

### OpenSearch Dashboards — index browser (port 5601)

**Local machine:** Open tunnel on port 5601, then open `http://localhost:5601`.

**List all indices:**  
- Menu (☰) → **Stack Management** → **Index Management**.  
- Shows all indices with document count and size.  
- The dictionary-rs indices you care about: `menu_item_en_us`, `menu_item_es_sv`, `menu_tree`, `role_*`.

**Query an index interactively:**
Menu → **Dev Tools** → Console. Type queries directly in the browser:

```
# List all indices with doc count
GET /_cat/indices?v

# Count documents in menu_item_en_us
GET /menu_item_en_us/_count

# Search for a specific menu item by name
GET /menu_item_en_us/_search
{
  "query": { "match": { "name": "Invoice" } }
}

# Delete all menu* indices (required after a database restore — see below)
DELETE /menu*
```

---

### Dkron — job scheduler (port 8899)

**Local machine:** Open tunnel on port 8899, then open `http://localhost:8899/ui`.

**List all scheduled jobs:**
The main page lists every job with its schedule (cron expression), last execution time, and last status (success/failed).

**Run a job manually:**  
- Click on the job name → **Run** (play button).  
- The job executes on the remote server. Useful for triggering a backup outside the scheduled window.

**View job execution history:**  
- Click on a job → **Executions** tab.  
- Shows the output and exit code of each past run.  
- Check here if a scheduled backup failed silently.

---

### dictionary-rs — REST API (via nginx, no tunnel needed)

dictionary-rs is not accessed directly. Its REST API is proxied by nginx and reachable on the public port 80:

**Local machine:**
```bash
curl http://<server-ip>/api/windows    # list all windows
curl http://<server-ip>/api/menus      # list all menu items
curl http://<server-ip>/api/processes  # list all processes
curl http://<server-ip>/api/roles      # list all roles
```

**Deleting all menu indices** (required after every database restore or when the Vue menu appears incomplete):

**Step 1 — Local machine:** Connect to the server via SSH:
```bash
ssh -i <path-to-ssh-key> -p <ssh-port> <user>@<server-ip>
```

**Step 2 — Remote server:** Enable wildcard deletion and delete all `menu*` indices:
```bash
# Enable wildcard deletion
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s -X PUT 'http://localhost:9200/_cluster/settings' \
  -H 'Content-Type: application/json' \
  -d '{"persistent":{"action.destructive_requires_name":false}}'

# Delete all menu* indices
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s -X DELETE 'http://localhost:9200/menu*'

# Verify — output should show only the header line with no indices
sudo docker exec adempiere-ui-gateway.opensearch \
  curl -s 'http://localhost:9200/_cat/indices?v&index=menu*'
```

After deleting the indices, run Export Application Dictionary in ZK, restart dictionary-rs, wait for indices to rebuild, then reload nginx.  
See [Installation Guide — Vue Menu Initialization](./installation.md) for the full procedure.

---

### MinIO S3 console (port 9090)

**Local machine:** Open tunnel on port 9090, then open `http://localhost:9090`.

- Log in with the MinIO credentials from `override.env` (`S3_ACCESS_KEY` / `S3_SECRET_KEY`).  
- The console shows all buckets, allows uploading/downloading files, and managing access policies.

---

### Keycloak (port 3333)

**Local machine:** Open tunnel on port 3333, then open `http://localhost:3333`.

- Log in with the Keycloak admin credentials from `override.env`.  
- From here you can manage users, roles, clients, and SSO settings for the ADempiere stack.

---

[Back to Services Overview](./services.md) | [Back to README](../README.md)
