# Dictionary-RS Service

## Abstract Overview

`dictionary-rs` is a high-performance caching layer for ADempiere's application dictionary.  
It intercepts dictionary change events published by ADempiere to Kafka, stores the resulting data in OpenSearch, and answers REST queries directly from the cache — bypassing the Java gRPC server for these lookups.  
This reduces response time from approximately 1 second (Java gRPC path) to
approximately 47 ms.

The service is written in Rust and exposes a REST API.  
It has no persistent state of its own: OpenSearch is its store, and Kafka is its change feed.  
If the OpenSearch index is lost or corrupted, ADempiere republishes the relevant topics and the cache is rebuilt automatically.

---

## Detailed Description

### Role in the Stack

In the ADempiere UI Gateway, the frontend (Vue or ZK) needs to load window, form, process,
browser, and menu definitions every time a user opens a screen.  
These definitions come from ADempiere's application dictionary (AD_Window, AD_Form, AD_Process, etc.).  
Loading them through the Java gRPC server on every request is slow (~1 s). `dictionary-rs` provides a fast read path (~47 ms) by serving these definitions from an OpenSearch index.

```
ADempiere (Java) ──Kafka──► dictionary-rs ──► OpenSearch (index)
                                  ▲                   │
Frontend (Vue/ZK) ──nginx──Envoy──┘◄──────────────────┘
                                  REST :50051
```

### Data Flow

1. **Write path** (dictionary update):
   - An ADempiere event (window change, new form, role update, etc.) is published to one of the
     seven Kafka topics.
   - `dictionary-rs` consumes the message, transforms it, and indexes the result in OpenSearch.

2. **Read path** (frontend request):
   - The frontend sends a REST request to nginx → Envoy → `dictionary-rs` (port 50051 internal).
   - `dictionary-rs` queries OpenSearch and returns the result directly without touching ADempiere.

### Kafka Topics

`dictionary-rs` subscribes to seven topics (configurable via `KAFKA_QUEUES`):

| Topic       | ADempiere entity |
|-------------|-----------------|
| `browser`   | AD_Browse (Smart Browse) |
| `form`      | AD_Form |
| `process`   | AD_Process |
| `window`    | AD_Window |
| `menu_item` | AD_Menu (individual items) |
| `menu_tree` | AD_TreeNodeMM (menu tree structure) |
| `role`      | AD_Role |

### REST API Endpoints

All endpoints are served under `/api/dictionary/` and `/api/security/`:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/dictionary/windows[/{id}]` | Window definitions |
| GET | `/api/dictionary/forms[/{id}]` | Form definitions |
| GET | `/api/dictionary/processes[/{id}]` | Process definitions |
| GET | `/api/dictionary/browsers[/{id}]` | Smart Browse definitions |
| GET | `/api/security/menus` | Menu items (filterable by language, client, role, user, search text) |
| GET | `/api/dictionary/system-info` | Service health / version info |

Menu query parameters: `language`, `client_id`, `role_id`, `user_id` (optional), `search_value`.

### OpenSearch Index Naming

Menu items are indexed per language, client, role, and optionally user:

| Scope | Index name pattern |
|-------|--------------------|
| English, by client | `menu_<client_id>` |
| English, by client + role | `menu_<client_id>_<role_id>` |
| Translated, by client | `menu_<language>_<client_id>` |
| Translated, by client + role | `menu_<language>_<client_id>_<role_id>` |

### Configuration (Environment Variables)

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `7878` | Internal HTTP port |
| `KAFKA_ENABLED` | `Y` | Enable/disable Kafka consumer |
| `KAFKA_QUEUES` | `browser form process window menu_item menu_tree role` | Space-separated topic list |
| `KAFKA_HOST` | `0.0.0.0:29092` | Kafka broker address |
| `KAFKA_GROUP` | `default` | Consumer group |
| `OPENSEARCH_URL` | `http://localhost:9200` | OpenSearch endpoint |
| `RUST_LOG` | `info` | Log level |
| `TZ` | `America/Caracas` | Container time zone |

### Deployment in adempiere-ui-gateway

- **Service name:** `dictionary-rs`
- **Container name:** `adempiere-ui-gateway.dictionary-rs`
- **Image:** `ghcr.io/adempiere/dictionary-rs:1.6.5`
- **Profile:** `all, cache`
- **Internal port:** `50051` (exposed via Envoy)
- **Dependencies:** `opensearch-node`, `adempiere-grpc-server`
- **Health check:** 90 s startup, 30 s interval, 10 s timeout

`dictionary-rs` is only active in the `cache` and `all` profiles. If the stack is started with a
profile that omits it (e.g. `vue` only), dictionary requests fall back to the Java gRPC server.

### Updating the Image

Updating `dictionary-rs` to a new version **does not require restarting ADempiere or clearing the
OpenSearch cache**. The procedure is:

1. Update `DICTIONARY_RS_IMAGE` in `docker-compose/env_template.env`.
2. Restart only the `dictionary-rs` container:
   ```bash
   cd docker-compose
   docker compose pull dictionary-rs
   docker compose up -d --no-deps dictionary-rs
   ```

**Why no other action is needed:**
- OpenSearch data lives in its own Docker volume — it is unaffected by restarting `dictionary-rs`.
- Kafka retains messages (default: 7 days). On reconnect, `dictionary-rs` resumes from its stored
  consumer group offset and processes any messages that arrived during the downtime automatically.
- No other container in the stack depends on `dictionary-rs` being restarted.

**Exception — index schema change:** If the release notes for the new version mention a breaking
change to the OpenSearch index structure, the indices must be cleared before restarting. In that
case follow the Cache Rebuild procedure below. ADempiere itself still does not need to be
restarted — Kafka retains the messages and `dictionary-rs` will re-index them on startup.

---

### Cache Rebuild

If the OpenSearch index needs to be cleared and rebuilt:

```bash
# Delete all dictionary indices
curl -X DELETE 'http://<host>:9200/menu*'
curl -X DELETE 'http://<host>:9200/window*'
# ... repeat for other topics

# Restart dictionary-rs to trigger re-subscription and re-indexing via Kafka
docker compose restart dictionary-rs
```

ADempiere must have the Kafka connector active to republish the topics. If needed, trigger a
manual republish from ADempiere's Kafka connector configuration.

### Performance Reference

| Path | Typical response time |
|------|-----------------------|
| Java gRPC server (direct) | ~1 020 ms |
| dictionary-rs via OpenSearch | ~47 ms |

Source: upstream benchmarks in the [dictionary_rs repository](https://github.com/adempiere/dictionary_rs).
