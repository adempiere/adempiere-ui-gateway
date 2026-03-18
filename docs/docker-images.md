# Docker Images - Version Management

**Date:** 2026-03-18
**Purpose:** Track and manage Docker images used in the ADempiere UI Gateway stack

---

## Overview

The ADempiere UI Gateway stack uses Docker images from three sources:

1. **SHW Customizations** (`marcalwestf/*` on Docker Hub)
   - Custom Westfalia implementations
   - Should **remain** on Docker Hub (marcalwestf namespace)
   - Not part of upstream ADempiere migration

2. **ADempiere Core** (`ghcr.io/adempiere/*`)
   - Official ADempiere services
   - Migrated from Docker Hub to GitHub Container Registry
   - Published at: https://github.com/orgs/adempiere/packages

3. **Third-party / official images** (PostgreSQL, MinIO, Envoy, nginx, Kafka, OpenSearch, Keycloak, DKron)
   - Maintained by their respective upstream projects
   - Not part of any migration — kept as-is

---

## Current Image Inventory

### SHW Customizations (Stay on Docker Hub)

These are Systemhaus-Westfalia customizations and should **NOT** be migrated to the ADempiere namespace:

| Image | Current Version | Registry | Status |
|-------|----------------|----------|--------|
| adempiere-shw-zk | jetty-3.9.4.001-shw-1.1.48 | marcalwestf | ✓ Active |
| adempiere-processors-service | alpine-1.1.18 | marcalwestf | ✓ Active |
| adempiere-grpc-server | 3.9.4.001-shw-1.0.34 | marcalwestf | ✓ Active |
| adempiere-vue | 0.0.8 | marcalwestf | ✓ Active |

**Repositories:**
- https://github.com/Systemhaus-Westfalia/adempiere-shw-zk
- https://github.com/Systemhaus-Westfalia/adempiere-processors-service
- https://github.com/Systemhaus-Westfalia/adempiere-grpc-server
- https://github.com/Systemhaus-Westfalia/adempiere-vue

### ADempiere Core (Migrated)

Successfully migrated to GitHub Container Registry:

| Image | Current Version | Registry | Status |
|-------|----------------|----------|--------|
| s3-gateway-rs | 1.2.8 | ghcr.io/adempiere | ✅ Migrated |
| adempiere-report-engine-service | 1.4.2-alpine | ghcr.io/adempiere | ✅ Migrated |
| dictionary-rs | 1.6.5 | ghcr.io/adempiere | ✅ Migrated |
| adempiere-landing-page | alpine-1.0.4 | ghcr.io/adempiere | ✅ Migrated |

**Packages:**
- https://github.com/adempiere/s3_gateway_rs/pkgs/container/s3-gateway-rs
- https://github.com/adempiere/adempiere-report-engine-service/pkgs/container/adempiere-report-engine-service
- https://github.com/adempiere/dictionary_rs/pkgs/container/dictionary-rs
- https://github.com/adempiere/adempiere-landing-page/pkgs/container/adempiere-landing-page

---

## Version Checking Script

### check-docker-images.sh

A bash script that automatically checks all Docker images used in the stack and reports:
- Current version in `env_template.env`
- Latest available version from registries
- Migration status (migrated / not migrated / N/A)
- Image type (SHW Custom / ADempiere Core / Legacy)

**Location:** `/docs/check-docker-images.sh`

**Usage:**

```bash
cd adempiere-ui-gateway/docs

# Basic usage (Docker Hub only)
./check-docker-images.sh

# With GitHub token (for GitHub Container Registry)
./check-docker-images.sh YOUR_GITHUB_TOKEN
```

**Output Example:**

```
Image                          Type            Registry/Namespace        Current              Latest          Status
------------------------------ --------------- ------------------------- -------------------- --------------- ------
S3 Gateway                     ADempiere Core   ghcr.io/adempiere         1.2.8                N/A             ✓
ZK UI (SHW)                    SHW Custom       docker.io/marcalwestf     jetty-3.9.4.001-...  jetty           --
Dictionary Service             Legacy (migrate) docker.io/openls          1.6.2                1.6.3           ✗ ⚠
Landing Page                   Legacy (migrate) docker.io/openls          alpine-1.0.3         1.0.3           ✗ ⚠
```

**Legend:**
- ✅ `✓` - Migrated to ghcr.io/adempiere
- `--` - Not applicable (SHW customization)
- ❌ `✗` - Not migrated yet
- ⚠️ - Newer version available

**Requirements:**
- `curl` - HTTP client
- `jq` - JSON parser

```bash
# Install on Ubuntu/Debian
sudo apt install curl jq

# Install on Mac
brew install curl jq
```

---

## Updating Image Versions

### Step-by-Step Process

#### 1. Check for Updates

Run the version checking script:

```bash
cd docs
./check-docker-images.sh
```

Look for images with ⚠️ (newer version available).

#### 2. Update env_template.env

Edit the main configuration file:

```bash
cd docker-compose
nano env_template.env
```

Find the image variable and update the version:

```bash
# Before
VUE_UI_IMAGE="marcalwestf/adempiere-vue:0.0.7"

# After
VUE_UI_IMAGE="marcalwestf/adempiere-vue:0.0.8"
```

#### 3. Restart the Stack

```bash
# Stop all services
./stop-all.sh

# Start with updated images
./start-all.sh

# Or for specific services
docker compose pull adempiere-vue
docker compose up -d --force-recreate adempiere-vue
```

#### 4. Verify

Check that the new version is running:

```bash
docker images | grep adempiere-vue
docker ps | grep adempiere-vue
docker logs adempiere-ui-gateway.vue
```

---

## Migration Guidelines

### When to Migrate to ghcr.io/adempiere

Images should be migrated if:
- ✅ They are **core ADempiere services** (not customizations)
- ✅ They are currently on `openls` namespace
- ✅ The source repository is under `adempiere` organization on GitHub

### When NOT to Migrate

Images should remain on Docker Hub if:
- ❌ They are **Systemhaus-Westfalia customizations** (marcalwestf namespace)
- ❌ They contain client-specific business logic
- ❌ They are forks of upstream ADempiere with custom patches

### Migration Process

For ADempiere core images still on Docker Hub:

1. **Verify upstream repository**
   - Check if repo is under `github.com/adempiere/`

2. **Follow migration guide**
   - Use GitHub Actions workflow to publish to ghcr.io
   - See GitHub Packages documentation (links in Related Documentation section)

3. **Update gateway configuration**
   - Change `openls/image:tag` → `ghcr.io/adempiere/image:tag`
   - Update `env_template.env`

4. **Test thoroughly**
   - Pull new image
   - Restart services
   - Verify functionality

---

## Related Documentation

- **GitHub Container Registry:** https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- **Docker Hub to GHCR Migration:** https://docs.github.com/en/packages/learn-github-packages/migrating-to-the-container-registry-from-the-docker-registry
- **ADempiere Organization:** https://github.com/adempiere
- **Systemhaus-Westfalia Organization:** https://github.com/Systemhaus-Westfalia

---

## Package Registries

### GitHub Container Registry (ghcr.io)

- **Organization:** https://github.com/orgs/adempiere/packages
- **Authentication:** Requires GitHub token with `read:packages` scope
- **Pull:** `docker pull ghcr.io/adempiere/image:tag`

### Docker Hub (docker.io)

- **Marcalwestf (SHW):** https://hub.docker.com/u/marcalwestf
- **OpenLS (Legacy):** https://hub.docker.com/u/openls
- **Pull:** `docker pull marcalwestf/image:tag`

---

**Document Version:** 1.0
**Created:** 2026-03-03
**Maintained By:** Systemhaus-Westfalia Development Team
