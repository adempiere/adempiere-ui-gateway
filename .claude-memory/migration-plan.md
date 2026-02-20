# Migration Plan: SHW → adempiere/adempiere-ui-gateway

**Status:** DRAFT — under review
**Goal:** Move `Systemhaus-Westfalia/adempiere-ui-gateway` (branch `adempiere-trunk`) to its upstream origin `adempiere/adempiere-ui-gateway`.

**Progress:**
- ✅ `marcalwestf` services (adempiere-zk, processors, grpc-server, vue): source repos confirmed, local clones available
- ⏸️ `openls` services (s3-gateway-rs, dictionary-rs, report-engine, landing-page): awaiting GitHub repo URLs from developers
- ✅ Customization library (`adempiere-shw`): confirmed
- ✅ Target registry confirmed: `ghcr.io/adempiere/`

**Scope:**
- 8 containerized services (4 `marcalwestf` confirmed + 4 `openls` pending)
- 1 customization library repository (not containerized)
- 1 gateway/orchestration repository

---

## Constraints (agreed)

- (a) External images (envoy, kafka, opensearch, postgres, nginx, etc.) stay as-is.
- (b) Images currently published under `Systemhaus-Westfalia` / `marcalwestf` must be republished under the `adempiere` GitHub org.
- (c) Branch names and tag/version conventions for the migrated repos are TBD — must be decided before any release is cut.
- (d) The four services to migrate are: adempiere-zk, adempiere-processors-service, adempiere-grpc-server, adempiere-vue. Source repos need to be confirmed for all except grpc-server.
- (e) CI/CD: use Systemhaus-Westfalia workflows as the reference (they are more up to date than adempiere's). Adapt `publish.yml` to publish to the adempiere org. Compare with adempiere's existing workflow files.
- (f) `svfe-api-firmador` (El Salvador e-invoicing) is NOT migrated — it stays Westfalia-specific.

---

## Part 1 — Complete Container Inventory

### 1a — Images kept as-is (no migration needed)

These are official or third-party images maintained by upstream projects. We do not control these images and they remain unchanged.

| Service | Image | Source/Maintainer |
|---|---|---|
| postgresql-service | `postgres:14.5` | PostgreSQL.org (official) |
| s3-storage | `quay.io/minio/minio:RELEASE.2025-07-23T15-54-02Z` | MinIO Inc. (official) |
| s3-client | `quay.io/minio/mc:RELEASE.2025-07-21T05-28-08Z` | MinIO Inc. (official) |
| envoy-grpc-proxy | `envoyproxy/envoy:v1.37.0` | Envoy Proxy (CNCF official) |
| nginx-ui-gateway | `nginx:1.27.0-alpine3.19` | nginx.org (official) |
| zookeeper | `confluentinc/cp-zookeeper:7.6.1` | Confluent (official Kafka distribution) |
| kafka | `confluentinc/cp-kafka:7.6.1` | Confluent (official Kafka distribution) |
| kafdrop | `obsidiandynamics/kafdrop:4.0.1` | ObsidianDynamics (third-party) |
| opensearch | `opensearchproject/opensearch:2.15.0` | OpenSearch Project (official) |
| opensearch-dashboards | `opensearchproject/opensearch-dashboards:2.15.0` | OpenSearch Project (official) |
| keycloak-service | `keycloak/keycloak:23.0.7` | Keycloak (official) |
| scheduler-dkron | `dkron/dkron:3.2.7` | dkron (official) |
| svfe-api-firmador | `svfe/svfe-api-firmador:v20230109` | **Excluded** — Westfalia-specific (constraint f) |

### 1b — Images that MUST be migrated to `ghcr.io/adempiere/`

**Context:** Both `openls/*` and `marcalwestf/*` Docker Hub namespaces were created as temporary publishing locations while the proper adempiere GitHub packages infrastructure was being set up. ALL artifacts from both namespaces will migrate to `ghcr.io/adempiere/` (GitHub Container Registry), visible at https://github.com/orgs/adempiere/packages.

**Total services to migrate:** 8

#### Group 1: `marcalwestf/*` images (4 services) ✅ CONFIRMED

| # | Service | Current image | Docker Hub | Source repo | Branch | Tag | Local directory |
|---|---|---|---|---|---|---|---|
| 1 | adempiere-zk | `marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.45` | [link](https://hub.docker.com/u/marcalwestf) | `Systemhaus-Westfalia/adempiere-shw-zk` | `master` | `3.9.4.001-shw-1.1.45` | `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-shw-zk` |
| 2 | processor | `marcalwestf/adempiere-processors-service:alpine-1.1.16` | [link](https://hub.docker.com/u/marcalwestf) | `Systemhaus-Westfalia/adempiere-processors-service` | `feature/shw/customizations` | `1.1.16` | `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-processors-service_SHW` |
| 3 | vue-grpc-server | `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30` | [link](https://hub.docker.com/u/marcalwestf) | `Systemhaus-Westfalia/adempiere-grpc-server` | `feature/shw/master` | `1.0.30` (in use) | `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-grpc-server_SHW` |
| 4 | vue-ui | `marcalwestf/adempiere-vue:0.0.5` | [link](https://hub.docker.com/u/marcalwestf) | `Systemhaus-Westfalia/adempiere-vue` | `develop` | `0.0.6` | `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-vue_SHW` |

#### Group 2: `openls/*` images (4 services) ⏸️ PENDING — ask developers for repo URLs

| # | Service | Current image | Docker Hub | Source repo | Notes |
|---|---|---|---|---|---|
| 5 | s3-gateway-rs | `openls/s3-gateway-rs:1.2.7` | [link](https://hub.docker.com/r/openls/s3-gateway-rs) | **TBC** | Not visible in public `openls` or `Systemhaus-Westfalia` orgs |
| 6 | dictionary-rs | `openls/dictionary-rs:1.5.5` | [link](https://hub.docker.com/r/openls/dictionary-rs) | **TBC** | idem |
| 7 | report-engine | `openls/adempiere-report-engine-service:alpine-1.3.7` | [link](https://hub.docker.com/r/openls/adempiere-report-engine-service) | **TBC** | idem |
| 8 | adempiere-site | `openls/adempiere-landing-page:alpine-1.0.3` | [link](https://hub.docker.com/r/openls/adempiere-landing-page) | **TBC** | idem |

**Note on `openls` namespace:** The `openls` Docker Hub namespace was created as a temporary workaround when artifacts were not allowed to be published to the `adempiere` GitHub org. The GitHub `openls` org exists (contact: info.openls@gmail.com) but the 4 service repos above are not visible in their public repos — they may be private or under different names. **Action required:** obtain GitHub repo URLs from developers.

**Target registry for ALL 8 services:** `ghcr.io/adempiere/<name>` (GitHub Container Registry)
**Packages page:** https://github.com/orgs/adempiere/packages

**Important context:**
Two services already have **legacy/non-working packages** published at `ghcr.io/adempiere/`:
- `adempiere-vue` (111k downloads) — legacy version, not currently functional
- `adempiere-grpc-server` (33.9k downloads) — legacy version, not currently functional

The migrated images will land at the same package names but will be **completely new/rewritten versions** based on the working SHW fork code. The legacy packages will be replaced.

**Open questions:**
1. Confirm source repo names and active branches for all `openls` services (s3-gateway-rs, dictionary-rs, report-engine, landing-page) — ask developers (constraint d)
2. Should the legacy packages be archived/deprecated explicitly before publishing the new versions?

---

## Part 2 — Per-Service Migration (8 services total)

### Common pattern for each service

1. Confirm source repo name and branch in `Systemhaus-Westfalia` or `adempiere` GitHub org
2. Fork / create the repo under `adempiere` GitHub org (if not already there)
3. Decide target branch name and tag convention (constraint c)
4. Push code into the new repo
5. Adapt `publish.yml` to publish Docker image to `ghcr.io/adempiere/<name>` (see Part 4)
6. Add required org-level secrets
7. Cut a release and verify image is accessible at `ghcr.io/adempiere/<name>`
8. Update the corresponding image variable in `env_template.env`

---

## Part 2a — Containerized Services

### adempiere-shw-zk (ZK UI) ✅

- Current image: `marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.45`
- Source repo: `Systemhaus-Westfalia/adempiere-shw-zk`
- Branch: `master`
- Tag: `3.9.4.001-shw-1.1.45`
- Local directory: `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-shw-zk`
- Future image: `ghcr.io/adempiere/adempiere-zk:<tag>`
- `env_template.env` variable: `ADEMPIERE_ZK_IMAGE`
- Note: image name currently has `shw-` infix — decide whether to drop or keep in new tag

### adempiere-processors-service ✅

- Current image: `marcalwestf/adempiere-processors-service:alpine-1.1.16`
- Source repo: `Systemhaus-Westfalia/adempiere-processors-service`
- Branch: `feature/shw/customizations`
- Tag: `1.1.16`
- Local directory: `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-processors-service_SHW`
- Future image: `ghcr.io/adempiere/adempiere-processors-service:<tag>`
- `env_template.env` variable: `ADEMPIERE_PROCESSOR_IMAGE`

### adempiere-grpc-server ✅

- Current image: `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30`
- Source repo: `Systemhaus-Westfalia/adempiere-grpc-server`
- Branch: `feature/shw/master`
- Tag: `1.0.30` (in use)
- Local directory: `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-grpc-server_SHW`
- Workflows confirmed: `ci.yml` and `publish.yml`
- Future image: `ghcr.io/adempiere/adempiere-grpc-server:<tag>` (replaces legacy package)
- `env_template.env` variable: `VUE_BACKEND_GRPC_SERVER_IMAGE`
- **Additional action:** apply Groovy `build.gradle` fix (add `groovy:3.0.22` + `groovy-jsr223:3.0.22`) before first release from new repo

### adempiere-vue (Vue UI) ✅

- Current image: `marcalwestf/adempiere-vue:0.0.5`
- Source repo: `Systemhaus-Westfalia/adempiere-vue`
- Branch: `develop`
- Tag: `0.0.6`
- Local directory: `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-vue_SHW`
- Future image: `ghcr.io/adempiere/adempiere-vue:<tag>` (replaces legacy package)
- `env_template.env` variable: `VUE_UI_IMAGE`

### s3-gateway-rs ⏸️ PENDING

- Current image: `openls/s3-gateway-rs:1.2.7`
- Source repo: **TBC — ask developers**
- Future image: `ghcr.io/adempiere/s3-gateway-rs:<tag>`
- `env_template.env` variable: `S3_GATEWAY_RS_IMAGE`

### dictionary-rs ⏸️ PENDING

- Current image: `openls/dictionary-rs:1.5.5`
- Source repo: **TBC — ask developers**
- Future image: `ghcr.io/adempiere/dictionary-rs:<tag>`
- `env_template.env` variable: `DICTIONARY_RS_IMAGE`

### adempiere-report-engine-service ⏸️ PENDING

- Current image: `openls/adempiere-report-engine-service:alpine-1.3.7`
- Source repo: **TBC — ask developers**
- Future image: `ghcr.io/adempiere/adempiere-report-engine-service:<tag>`
- `env_template.env` variable: `VUE_REPORT_GRPC_SERVER_IMAGE`

### adempiere-landing-page ⏸️ PENDING

- Current image: `openls/adempiere-landing-page:alpine-1.0.3`
- Source repo: **TBC — ask developers**
- Future image: `ghcr.io/adempiere/adempiere-landing-page:<tag>`
- `env_template.env` variable: `ADEMPIERE_SITE_IMAGE`

---

## Part 2b — Customization Library Repository (not containerized)

### Understanding Customizations

**What is a customization?**
A customization is a modification or addition to ADempiere functionality required for:
- National legal/regulatory compliance (e.g., tax rules, invoicing formats)
- Customer-specific business processes
- Industry-specific requirements

In the SHW implementation, all customizations are consolidated into a **single library repository** that is consumed as a Maven dependency by the containerized services.

### adempiere-customizations (Customization Library) ✅

This is **not a containerized service** — it is a library repository that publishes Maven artifacts consumed by `adempiere-shw-zk`, `adempiere-processors-service`, and `adempiere-grpc-server`.

**Current state (SHW fork):**
- Repository: `Systemhaus-Westfalia/adempiere-shw`
- Forked from: `adempiere/adempiere-customizations`
- Branch: `main`
- Tag: `3.9.4.001-1.1.48`
- Local directory: `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-shw`
- Published Maven artifact: `com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48`
- Published to: `https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw`

**Target state (migrated to adempiere org):**
- Repository: `adempiere/adempiere-customizations`
- Published Maven artifact: `io.github.adempiere:adempiere-customizations:<version>`
- Published to: `https://maven.pkg.github.com/adempiere/adempiere-customizations`

**SHW-specific customizations in this repo:**

1. **Integrates `lsv-general` repository** (SHW's El Salvador localization)
   - Source repo: `Systemhaus-Westfalia/lsv-general`
   - GitHub: https://github.com/Systemhaus-Westfalia/lsv-general/tree/master
   - Local directory: `/data2/entwicklung/shw_repositories_2024/lsv-general`
   - Maven artifact: `com.shw:lsv-general:1.0.41`
   - Declared in:
     - File: `shw_libs/build.gradle`
     - Line: 161
     - Content: `api "com.shw:lsv-general:1.0.41"`

2. **References ADempiere core**
   - File: `build.gradle`
   - Lines: 32-50
   - Defines `libraryRepo`, `baseVersion`, `baseGroupId`, `publishGroupId`

**Services that depend on this customization library:**

| Service | File | Line | Current Reference |
|---|---|---|---|
| `adempiere-shw-zk` | `build.gradle` | 46 | `implementation 'com.shw:adempiere-shw.shw_libs:' + adempiereSHWRelease` |
| `adempiere-processors-service` | `build.gradle` | 188 | `implementation 'com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48'` |
| `adempiere-grpc-server` | `build.gradle` | 127 | `implementation 'com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48'` |

Additionally, `adempiere-shw-zk` references the official ADempiere ZK UI:
- File: `build.gradle`
- Line: 141
- Content: `isrc 'https://github.com/adempiere/zk-ui/releases/download/' + adempiereZKRelease + '/zk-ui.war'`

### Migration Strategy for Customizations

**Goal:** Migrate the customization *mechanism* to the adempiere org, but anonymize SHW-specific customizations so other implementors can add their own.

**Steps:**

1. **Fork/update `adempiere/adempiere-customizations`** with the structure from `Systemhaus-Westfalia/adempiere-shw`

2. **Anonymize SHW-specific integrations** by converting them to commented stubs:

   **Before (SHW-specific):**
   ```gradle
   // shw_libs/build.gradle, line 161
   api "com.shw:lsv-general:1.0.41"
   ```

   **After (anonymized stub):**
   ```gradle
   // shw_libs/build.gradle, line 161
   // Add your organization's customization repositories here:
   // api "your.org:your-customization-repository:version"
   //
   // Example (SHW implementation - El Salvador localization, commented out):
   // api "com.shw:lsv-general:1.0.41"
   ```

3. **Update Maven publishing coordinates** in `build.gradle`:

   **Before:**
   ```gradle
   ext {
       libraryRepo  = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"
       publishGroupId  = "com.shw"
   }
   ```

   **After:**
   ```gradle
   ext {
       libraryRepo  = "https://maven.pkg.github.com/adempiere/adempiere-customizations"
       publishGroupId  = "io.github.adempiere"
   }
   ```

4. **Update references in dependent services** to point to the new artifact:

   In `adempiere-shw-zk`, `adempiere-processors-service`, and `adempiere-grpc-server`:

   **Before:**
   ```gradle
   implementation 'com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48'
   ```

   **After:**
   ```gradle
   implementation 'io.github.adempiere:adempiere-customizations:3.9.4.001'
   ```

5. **Update `env_template.env` and `.env`** in the gateway repo — any references to SHW customization versions need to be updated to point to the adempiere artifact versions.

6. **Document for implementors** how to:
   - Fork `adempiere/adempiere-customizations` for their own organization
   - Add their customization repositories to the dependencies (uncommenting the stub)
   - Publish to their own Maven registry (GitHub Packages)
   - Update the three dependent service repos to consume their customizations
   - Configure GitHub Actions secrets for Maven publishing

### Recommendation

**Best practice:** Use a single customization integration repository (like `adempiere-customizations`) that aggregates all organization-specific customizations. While it's technically possible to have multiple customization repositories, this adds unnecessary complexity.

---

## Part 3 — Gateway Repository Migration

### Source vs target

- Source: `Systemhaus-Westfalia/adempiere-ui-gateway:adempiere-trunk` (local clone: this repo)
- Target: `adempiere/adempiere-ui-gateway:main` (exists, ~187 commits, GPL-3.0)

### Steps

1. **Compare** `adempiere-trunk` with `adempiere/adempiere-ui-gateway:main` — identify commits not yet upstream
2. **Clean** before opening PR:
   - Replace deployment-specific values in `env_template.env`:
     - `HOST_IP=erp-adempiere.westfalia-it.com` → `HOST_IP=<your-host-ip>`
     - `HOST_TIMEZONE="America/El_Salvador"` → `HOST_TIMEZONE="<your-timezone>"`
   - Remove or generalize any remaining Westfalia-specific service configurations
   - Verify `svfe-api-firmador` has no references in the PR delta
3. **Update all eight image references** in `env_template.env` (after Part 2 services are published):

   | Variable | From | To |
   |---|---|---|
   | `ADEMPIERE_ZK_IMAGE` | `marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.45` | `ghcr.io/adempiere/adempiere-zk:<tag>` |
   | `ADEMPIERE_PROCESSOR_IMAGE` | `marcalwestf/adempiere-processors-service:alpine-1.1.16` | `ghcr.io/adempiere/adempiere-processors-service:<tag>` |
   | `VUE_BACKEND_GRPC_SERVER_IMAGE` | `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30` | `ghcr.io/adempiere/adempiere-grpc-server:<tag>` |
   | `VUE_UI_IMAGE` | `marcalwestf/adempiere-vue:0.0.5` | `ghcr.io/adempiere/adempiere-vue:<tag>` |
   | `S3_GATEWAY_RS_IMAGE` | `openls/s3-gateway-rs:1.2.7` | `ghcr.io/adempiere/s3-gateway-rs:<tag>` |
   | `DICTIONARY_RS_IMAGE` | `openls/dictionary-rs:1.5.5` | `ghcr.io/adempiere/dictionary-rs:<tag>` |
   | `VUE_REPORT_GRPC_SERVER_IMAGE` | `openls/adempiere-report-engine-service:alpine-1.3.7` | `ghcr.io/adempiere/adempiere-report-engine-service:<tag>` |
   | `ADEMPIERE_SITE_IMAGE` | `openls/adempiere-landing-page:alpine-1.0.3` | `ghcr.io/adempiere/adempiere-landing-page:<tag>` |
4. **Add `.github/workflows/ci.yml`** (currently absent from this repo) — at minimum a syntax check (`docker compose config`) on PRs
5. **Open PR** from `adempiere-trunk` → `adempiere/adempiere-ui-gateway:main`
6. **Update documentation** (see Part 5)

---

## Part 4 — CI/CD Changes for Service Repos (constraint e)

For each of the **8 service repos**, only `publish.yml` needs significant changes. `ci.yml` (build/test) usually requires no registry changes.

| What | From | To |
|---|---|---|
| Image destination (marcalwestf) | `docker.io/marcalwestf/<name>` | `ghcr.io/adempiere/<name>` |
| Image destination (openls) | `docker.io/openls/<name>` | `ghcr.io/adempiere/<name>` |
| Registry login | Docker Hub secrets (`DOCKERHUB_USER`, `DOCKERHUB_TOKEN`) | `GITHUB_TOKEN` (automatic for ghcr.io on public repos) |
| Publish trigger branch | current SHW/openls branch | agreed adempiere branch (TBD, constraint c) |
| Version tag | `shw-x.y.z` suffix (marcalwestf) | agreed community convention (TBD, constraint c) |

**Registry confirmed:** `ghcr.io/adempiere/` (GitHub Container Registry) — artifacts visible at https://github.com/orgs/adempiere/packages

**Open question (constraint e):** Are the CI/CD workflows in `adempiere` org repos more or less up-to-date than the SHW ones? Need to compare before deciding which is the base for the adapted workflow.

---

## Part 5 — Documentation Updates

- Update all references to `Systemhaus-Westfalia` GitHub URLs in `docs/`
- Update `CLAUDE.md`: branch reference `adempiere-trunk` → `main` (or whatever the target is)
- Update `.claude-memory/` files: change repo URLs, remove SHW-specific context
- Update `README.md`: remove any Westfalia-specific URLs; verify JDK note is already removed
- Check `swagger/` directory for any SHW-specific references

---

## Part 6 — Execution Order

```
Phase 1  Audit
         ├── Confirm source repo names/branches for all 8 services
         ├── Registry confirmed: ghcr.io/adempiere/ (GitHub Container Registry)
         └── Identify which services already have repos in adempiere org

Phase 2  Per-service (8 services — can run in parallel)
         ├── Fork/create repo under adempiere org
         ├── Decide branch name + tag convention (constraint c)
         ├── Push code
         ├── Adapt publish.yml → publish to ghcr.io/adempiere/<name>
         ├── Add org secrets
         └── Cut release → verify image at ghcr.io/adempiere/<name>

Phase 3  Gateway repo (after at least one image per service exists)
         ├── Update env_template.env — all 8 image references (see table in Part 3)
         ├── Clean deployment-specific content
         ├── Add .github/workflows/ci.yml
         └── Open PR to adempiere/adempiere-ui-gateway:main

Phase 4  Docs (parallel with Phase 3)
         └── Update all SHW references in docs/, CLAUDE.md, README.md

Phase 5  Smoke test
         └── Pull fresh on clean machine; full stack test (ZK + Vue + POS)
```

---

## Open Questions (to resolve before or during Phase 1)

1. ✅ **Resolved for `marcalwestf` services:** Source repos and branches confirmed
   - `adempiere-shw-zk`: `Systemhaus-Westfalia/adempiere-shw-zk`, branch `master` ✅
   - `adempiere-processors-service`: `Systemhaus-Westfalia/adempiere-processors-service`, branch `feature/shw/customizations` ✅
   - `adempiere-grpc-server`: `Systemhaus-Westfalia/adempiere-grpc-server`, branch `feature/shw/master` ✅
   - `adempiere-vue`: `Systemhaus-Westfalia/adempiere-vue`, branch `develop` ✅
2. ⏸️ **PENDING for `openls` services:** Obtain GitHub repo URLs from developers
   - `s3-gateway-rs`: **TBC**
   - `dictionary-rs`: **TBC**
   - `adempiere-report-engine-service`: **TBC**
   - `adempiere-landing-page`: **TBC**
3. ✅ **Resolved:** Registry preference is `ghcr.io/adempiere/` (GitHub Container Registry)
4. ✅ **Resolved:** `openls/` and `marcalwestf/` are both temporary Docker Hub namespaces — all 8 services migrate to `ghcr.io/adempiere/`
5. Tag/version convention after migration: keep `shw-` prefix or drop it?
6. Should the legacy `adempiere-vue` and `adempiere-grpc-server` packages be explicitly archived/deprecated before publishing the new versions?
7. Does someone with admin rights to the `adempiere` GitHub org need to be involved from Phase 1?
8. What is the target branch name in `adempiere/adempiere-ui-gateway` for this work — merge directly into `main` or via a feature branch?

---

## Additional Items (raised proactively)

- **Groovy `build.gradle` fix** (Service C): apply before first adempiere release so the issue is fixed at source, not just patched in the Dockerfile.
- **Divergence management**: once adempiere repos are live, define how Westfalia-specific patches flow back upstream vs. staying in the SHW fork.
- **`swagger/` directory**: check for SHW-specific references.
- **Secrets and org access**: coordinate with an `adempiere` org admin before Phase 2.
