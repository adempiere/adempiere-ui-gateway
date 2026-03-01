# Debugging Vue Frontend Through the Stack

When the Vue UI displays an error, the root cause is almost never in the browser itself — it is somewhere in the chain of containers behind it. This guide explains how to trace an error from the browser all the way to the gRPC server where ADempiere business logic runs.

## The Request Chain

Every API call made by the Vue UI (Firefox, Chrome, Opera) travels through this chain of containers:

```
Browser (Vue Single Page Application (SPA))
  │
  │  HTTP/JSON  [port 80, public]
  ▼
adempiere-ui-gateway.nginx-ui-gateway   (service: ui-gateway)
  │   Routes /api/* requests to Envoy
  │
  │  HTTP/JSON  [port 5555, internal network]
  ▼
adempiere-ui-gateway.envoy-grpc-proxy   (service: grpc-proxy)
  │   Transcodes HTTP/JSON → gRPC
  │
  │  gRPC  [port 50059, internal network]
  ▼
adempiere-ui-gateway.vue-grpc-server    (service: adempiere-grpc-server)
  │   Executes ADempiere business logic
  │
  │  SQL  [port 5432, internal network]
  ▼
adempiere-ui-gateway.postgresql         (service: postgresql-service)
```

The error message shown in the Vue UI is what the gRPC server returned, transcoded by Envoy into an HTTP response. The real cause — the Java stack trace — is in the gRPC server logs.

---

## Step-by-Step: Tracing an Error

### Step 1 — Read the error in the browser

Open the browser's developer tools before reproducing the error:

- Firefox / Chrome / Opera: **F12** → Network tab → check "Disable cache"
- Reproduce the action that causes the error
- In the Network tab, look for a request with a red status (4xx or 5xx)
- Click on it and read:
  - **Status code** — e.g. `500 Internal Server Error`
  - **Response body** — usually contains the error message text shown in the UI

This tells you *what* failed. The next steps tell you *why*.

**Record this information before moving on** — you will need it to reproduce the call with curl:

| What to capture | Where to find it in F12 |
|-----------------|-------------------------|
| Request URL and path | "Headers" tab → "Request URL" (contains business IDs, e.g. `/api/point-of-sales/1000000/process-order`) |
| Request method | "Headers" tab → "Request Method" (`GET`, `POST`, etc.) |
| Request body (payload) | "Request" tab → copy the JSON body |
| Auth token | "Headers" tab → `Authorization: Bearer <token>` |
| Business context | visible in the Vue UI: POS terminal number, order/ticket number, logged-in user name |

### Step 2 — Check nginx logs

nginx is the entry point. Check whether the request arrived and was routed correctly:

```bash
docker logs adempiere-ui-gateway.nginx-ui-gateway --tail 50
```

Look for lines containing the request path (e.g. `/api/point-of-sales/process-order`). A `502 Bad Gateway` here means nginx could not reach Envoy. A `404` means the path is not configured in nginx routing.

### Step 3 — Check Envoy logs

Envoy transcodes HTTP/JSON to gRPC and forwards to the gRPC server. Check whether transcoding succeeded and what gRPC status code came back:

```bash
docker logs adempiere-ui-gateway.envoy-grpc-proxy --tail 50
```

Relevant gRPC status codes returned by Envoy:

| gRPC status | HTTP equivalent | Meaning |
|-------------|-----------------|---------|
| `OK` (0) | 200 | Success |
| `INVALID_ARGUMENT` (3) | 400 | Bad request data (e.g. missing mandatory field) |
| `NOT_FOUND` (5) | 404 | Record not found in database |
| `INTERNAL` (13) | 500 | Unhandled exception in gRPC server — **look at Step 4** |
| `UNAVAILABLE` (14) | 503 | gRPC server is down or not reachable |

If Envoy shows `UNAVAILABLE`, the gRPC server container is the problem — check its health:

```bash
docker ps | grep vue-grpc-server
```

### Step 4 — Check the gRPC server logs (the real error)

This is where Java exceptions and ADempiere business logic errors are logged. This is almost always where the root cause lives:

```bash
docker logs adempiere-ui-gateway.vue-grpc-server --tail 100
```

Search for the specific exception:

```bash
# Show last errors with context
docker logs adempiere-ui-gateway.vue-grpc-server 2>&1 | grep -A 20 "Exception\|ERROR"

# Filter by a specific operation (e.g. POS order processing)
docker logs adempiere-ui-gateway.vue-grpc-server 2>&1 | grep -A 20 "processOrder\|PointOfSales"

# Follow live while reproducing the error
docker logs adempiere-ui-gateway.vue-grpc-server -f
```

The Java stack trace will tell you:
- The exception type (e.g. `NullPointerException`, `AdempiereException`)
- The exact class and line number where it failed
- The chain of calls that led to it

### Step 5 — Check the database if needed

If the gRPC server log points to a database query, missing record, or data integrity issue:

```bash
# Open a PostgreSQL session
docker exec -it adempiere-ui-gateway.postgresql psql -U adempiere -d adempiere

# Example: check if a record exists
SELECT * FROM c_pos WHERE c_pos_id = <your-pos-id>;

# Example: check active script rules
SELECT ad_rule_id, name, ruletype, eventtype
FROM ad_rule
WHERE isactive = 'Y' AND ruletype = 'S';
```

---

## Reproducing a Request with curl

Once you have the information from Step 1, you can replay the failing request directly from the server command line. This immediately answers the key question: is the bug in the Vue UI (wrong payload, missing field) or in the backend?

### Option A — Copy as cURL from the browser (fastest)

In the F12 Network tab, right-click the failing request and choose:
- Firefox: **"Copy Value" → "Copy as cURL"**
- Chrome / Opera: **"Copy" → "Copy as cURL (bash)"**

Paste the result in a terminal on the server host. This replays the exact same call, including the auth token and request body, without going through the Vue UI.

### Option B — Build the curl command manually

**Step 1 — Get an auth token** (or copy `Bearer <token>` from the `Authorization` header of any captured request):

```bash
# Replace HOST_IP, user, and password with your values from env_template.env
TOKEN=$(curl -s -X POST "http://${HOST_IP}/api/security/login" \
  -H "Content-Type: application/json" \
  -d '{"user_name":"<user>","user_pass":"<pass>","token":""}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
echo $TOKEN
```

**Step 2 — Call the API endpoint that failed.**

The IDs in the URL come from what you captured in Step 1:

- **`<pos-id>`** — the POS terminal ID (`C_POS_ID`). Read it directly from the failing request URL in F12 (e.g. `/api/point-of-sales/**1000000**/process-order` → pos-id = `1000000`). It is also shown in the Vue UI POS screen title or header.
- **`<order-id>`** — the current order/ticket ID (`C_Order_ID`). It appears in the request URL (e.g. `/api/point-of-sales/1000000/order/**2000042**/...`) or in the JSON request body as `"order_id"`. It is also visible as the ticket number in the Vue UI POS screen.

```bash
# Get POS terminal information
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://${HOST_IP}/api/point-of-sales/<pos-id>" | python3 -m json.tool

# Get a specific order
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://${HOST_IP}/api/point-of-sales/<pos-id>/order/<order-id>" | python3 -m json.tool

# Get payment methods for a POS terminal
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://${HOST_IP}/api/point-of-sales/<pos-id>/payment-methods" | python3 -m json.tool

# Process a POS order (POST with body copied from Step 1)
curl -s -X POST "http://${HOST_IP}/api/point-of-sales/<pos-id>/process-order" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '<request-body-from-step-1>' | python3 -m json.tool
```

### What the result tells you

| curl result | Meaning | Next step |
|-------------|---------|-----------|
| **2xx success** | Bug is in the Vue UI — it sends a different or wrong request | Compare what curl sent vs what the Vue UI sent |
| **Same error as the browser** | Bug is in the backend | Continue with Step 4 (gRPC server logs) |
| **400 / `INVALID_ARGUMENT`** | A required field is missing or has the wrong type | Compare the request body with the API spec |
| **401 Unauthorized** | Auth token has expired | Log in again to get a fresh token |
| **503 / no response** | gRPC server or Envoy is down | Check container status: `docker ps \| grep -E "envoy\|grpc-server"` |

### Calling Envoy directly (bypass nginx)

To confirm whether nginx or Envoy is the failing layer, call Envoy's port directly from inside the Docker network:

```bash
# Run from within any container on the same Docker network
docker exec adempiere-ui-gateway.nginx-ui-gateway \
  curl -s -H "Authorization: Bearer $TOKEN" \
  "http://grpc-proxy:5555/api/point-of-sales/<pos-id>" | python3 -m json.tool
```

If this succeeds but the external call fails → the problem is in nginx routing, not in the gRPC server.

---

## Quick Reference: Log Commands

```bash
# All containers — live log stream (Ctrl+C to stop)
docker logs adempiere-ui-gateway.nginx-ui-gateway  -f
docker logs adempiere-ui-gateway.envoy-grpc-proxy  -f
docker logs adempiere-ui-gateway.vue-grpc-server   -f

# Last N lines
docker logs adempiere-ui-gateway.vue-grpc-server --tail 200

# Errors only
docker logs adempiere-ui-gateway.vue-grpc-server 2>&1 | grep -i "error\|exception\|warn"

# With timestamps
docker logs adempiere-ui-gateway.vue-grpc-server --timestamps --tail 100
```

---

## Common Error Patterns

### "Mandatory field" errors

The Vue UI shows a message like `@FieldName@ @IsMandatory@` or `Field X is mandatory`.

- Cause: the gRPC server requires a field that the Vue UI did not send.
- Where to look: gRPC server logs will show the field name; check the Vue UI version and API compatibility.

### NullPointerException in MRule / ScriptEngine

```
java.lang.NullPointerException: Cannot invoke "javax.script.ScriptEngine.put(...)" because "engine" is null
```

- Cause: an `AD_Rule` with a `groovy:` or `javascript:` prefix is active, but the required ScriptEngine JAR is missing from the gRPC server classpath.
- See: [ScriptEngine NullPointerException](./troubleshooting.md#scriptengine-nullpointerexception-groovy-ad-rules)

### 502 Bad Gateway

The browser receives a 502 with no meaningful response body.

- Cause: nginx cannot reach Envoy, or Envoy cannot reach the gRPC server.
- Check: `docker ps | grep -E "envoy|grpc-server"` — is the container running and healthy?

### 503 Service Unavailable / gRPC UNAVAILABLE

- Cause: the gRPC server container is stopped, unhealthy, or still starting up.
- Check: `docker ps | grep vue-grpc-server` — look at the STATUS column.

---

## Tips

- **Always check the gRPC server log first.** The browser error message is a summary; the Java stack trace in the gRPC server log is the full story.
- **Use `-f` to follow logs live** while you reproduce the error in the browser. This avoids searching through old log entries.
- **The gRPC server writes to stderr**, so use `2>&1` when piping or redirecting its logs.
- **Envoy access logs** show every request with gRPC status code, upstream response time, and request path — useful for confirming that a request was received and forwarded.

---

[Back to README](../README.md) | [Previous: Debugging](./debugging.md) | [Next: Troubleshooting](./troubleshooting.md)

