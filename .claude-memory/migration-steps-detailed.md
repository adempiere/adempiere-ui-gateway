# ADempiere Stack Migration - Detailed Step-by-Step Guide

📝 **Status:** Draft for review
📅 **Last Updated:** 2026-02-21

---

## Purpose

This document provides precise, line-by-line instructions for migrating the ADempiere UI Gateway stack to publish all Docker images to the official adempiere organization's GitHub Container Registry. This includes:
- Four repositories already in adempiere org (openls namespace) that only need Docker publishing changes
- Four repositories from Systemhaus-Westfalia that need both repository migration and Docker publishing changes

Each service section contains:
- **File paths** - exact location of files to modify
- **Line numbers** - specific lines requiring changes
- **Before values** - current configuration
- **After values** - target configuration
- **Actions** - what to do (edit, add, delete, verify)

---

## Table of Contents

1. [Version Creation Strategy](#version-creation-strategy)
2. 🔄 [Service: s3-gateway-rs](#service-s3-gateway-rs)
3. ⬜ [Service: dictionary-rs](#service-dictionary-rs)
4. ⬜ [Service: adempiere-report-engine](#service-adempiere-report-engine)
5. ⬜ [Service: adempiere-site](#service-adempiere-site)
6. ⬜ [Service: adempiere-zk (ZK UI)](#service-adempiere-zk-zk-ui)
7. ⬜ [Service: adempiere-processor](#service-adempiere-processor)
8. ⬜ [Service: adempiere-grpc-server](#service-adempiere-grpc-server)
9. ⬜ [Service: vue-ui (Vue UI)](#service-vue-ui-vue-ui)
10. ⬜ [Library: adempiere-shw (Customization Library)](#library-adempiere-shw-customization-library)
11. ⬜ [Gateway: adempiere-ui-gateway](#gateway-adempiere-ui-gateway)
12. [Execution Order Recommendation](#execution-order-recommendation)
13. [Verification Checklist](#verification-checklist)
14. [Notes for Implementors (Customizations)](#notes-for-implementors-customizations)
15. [Appendix: Common Issues and Solutions](#appendix-common-issues-and-solutions)
16. [Document Maintenance](#document-maintenance)

---

## Version Creation Strategy

### Overview

The migration process requires creating **new versions** for all migrated services. The version/release creation happens AFTER code changes are committed but BEFORE updating the gateway's `env_template.env` and `.env` files.

### Version Workflow

For each service, the workflow is:

1. **Code Changes** → Make all repository/registry changes (build.gradle, publish.yml)
2. **Commit & Push** → Commit changes to target repository and branch
3. **Create Release** → Create GitHub Release with appropriate tag
4. **GitHub Actions** → Workflow automatically publishes Docker image/Maven artifact
5. **Verify Publication** → Confirm new version is available at `ghcr.io/adempiere/<service>`
6. **Update Gateway** → Reference new version in gateway's env files (Phase 4)

### Versioning Conventions

**Recommendation:** Use semantic versioning with a migration marker for the first adempiere-hosted release.

#### Option A: Increment Patch Version
- **Current SHW version:** `3.9.4.001-shw-1.1.45`
- **First adempiere version:** `3.9.4.001-1.1.46` (remove `-shw-`, increment last number)
- **Rationale:** Continuity, shows it's an evolution of the same codebase

#### Option B: Migration Marker Version
- **Current SHW version:** `3.9.4.001-shw-1.1.45`
- **First adempiere version:** `3.9.4.001-adempiere-1.0.0` (reset with `-adempiere-` marker)
- **Rationale:** Clear migration marker, fresh start for adempiere organization

#### Option C: Major Version Bump
- **Current SHW version:** `1.1.16` (processors-service)
- **First adempiere version:** `2.0.0`
- **Rationale:** Signals major organizational change, breaking change in artifact coordinates

**Decision Required:** Choose one versioning strategy and apply consistently across all services.

### Service-Specific Version Examples

Based on current versions in `env_template.env`:

| Service | Current Version | Suggested New Version (Option A) |
|---------|----------------|----------------------------------|
| adempiere-zk | `jetty-3.9.4.001-shw-1.1.45` | `jetty-3.9.4.001-1.1.46` |
| adempiere-processors-service | `alpine-1.1.16` | `alpine-1.1.17` |
| adempiere-grpc-server | `3.9.4.001-shw-1.0.30` | `3.9.4.001-1.0.31` |
| adempiere-vue | `0.0.5` | `0.0.6` |
| s3-gateway-rs | `1.2.7` | `1.2.8` |
| dictionary-rs | `1.5.5` | `1.5.6` |
| adempiere-report-engine-service | `alpine-1.3.7` | `alpine-1.3.8` |
| adempiere-landing-page | `alpine-1.0.3` | `alpine-1.0.4` |

### Release Creation Process (GitHub UI)

For each service repository:

1. **Navigate to Releases**
   - Go to `https://github.com/adempiere/<service-name>/releases`
   - Click "Create a new release" or "Draft a new release"

2. **Create Tag**
   - Click "Choose a tag"
   - Type new version tag (e.g., `3.9.4.001-1.1.46` or `alpine-1.1.17`)
   - Select "Create new tag: X.Y.Z on publish"

3. **Target Branch**
   - Select the target branch (e.g., `main`, `master`, `develop`)
   - Ensure all migration changes are committed to this branch

4. **Release Title**
   - Use format: `<Service Name> v<version> - Migration to adempiere`
   - Example: "ADempiere ZK v3.9.4.001-1.1.46 - Migration to adempiere"

5. **Release Description**
   - Document what changed:
     ```markdown
     ## Migration Release

     This is the first release under the `adempiere` organization.

     ### Changes
     - Migrated from Systemhaus-Westfalia to adempiere organization
     - Updated Docker registry: Docker Hub → ghcr.io/adempiere
     - Updated Maven artifacts: com.shw → io.github.adempiere (commented as stubs)
     - Updated Maven repositories: Systemhaus-Westfalia → adempiere

     ### Docker Image
     - `ghcr.io/adempiere/<service-name>:<version>`

     ### Breaking Changes
     - Maven artifact coordinates changed (for customization dependencies)
     - Customization dependencies commented out as stubs for generic template
     ```

6. **Publish Release**
   - Click "Publish release"
   - GitHub Actions workflow (named `publish.yml`, `publish.yaml`, `release.yml`, or `release.yaml` depending on repository) will trigger automatically
   - Monitor the Actions tab to verify successful build and publication
   - **Note:** Workflow naming is inconsistent across repositories - standardization is a migration goal

### Verification After Release

After creating each release, verify:

```bash
# For Docker images
docker pull ghcr.io/adempiere/<service-name>:<version>
docker images | grep adempiere

# For Maven artifacts (adempiere-shw only)
# Check GitHub Packages: https://github.com/adempiere/adempiere-customizations/packages
```

### When to Create Releases

**Timing:** Create releases service-by-service following the execution order (see below). Do NOT create all releases at once.

**Recommended Flow:**
1. Migrate one service completely (code, commit, release, verify)
2. Test the new Docker image/artifact
3. Move to next service
4. After ALL services have new versions → Update gateway env files

---

## Service: s3-gateway-rs

**Status:** 🔄 WIP

**Docker Compose Service Name:** `s3-gateway-rs`
**Repository Name:** `s3_gateway_rs`

### Migration Details

- **Source Repository:** `https://github.com/adempiere/s3_gateway_rs` ✅ Already in adempiere org
- **Source Branch:** `main`
- **Target Repository:** `https://github.com/adempiere/s3_gateway_rs` (same - no fork needed)
- **Target Branch:** `main` (or create new branch for migration)
- **Current Docker Image:** `openls/s3-gateway-rs:1.2.7` (Docker Hub)
- **Target Docker Image:** `ghcr.io/adempiere/s3-gateway-rs:<version>` (GitHub Container Registry)

**Note:** This repository is already in the adempiere organization. Migration only requires changing the publishing destination from Docker Hub to ghcr.io.

### File 1: `.github/workflows/release.yaml`

#### Change 1: Docker Login - Add Registry
- **Location:** Lines 53-58 (the Docker login action block)
- **What to change:** Replace the `with:` section (lines 55-58 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Docker Image Tags
- **Location:** Lines 69-71 (the `tags:` section)
- **What to change:** Replace lines 70-71 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_HUB_REPO_NAME }}:${{ github.event.release.tag_name }}
  ${{ secrets.DOCKER_HUB_REPO_NAME }}
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/s3-gateway-rs:${{ github.event.release.tag_name }}
  ghcr.io/adempiere/s3-gateway-rs:latest
  ```

#### Change 3: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_HUB_REPO_NAME` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `1.2.8` (or chosen version per strategy)
   - Target: `main` branch
   - Title: "S3 Gateway RS v1.2.8 - Migration to ghcr.io"

2. **GitHub Actions Publishes Image**
   - Workflow: `.github/workflows/release.yaml` triggers automatically
   - Builds and publishes: `ghcr.io/adempiere/s3-gateway-rs:1.2.8`
   - Platforms: `linux/amd64`, `linux/amd64/v2`, `linux/arm64/v8`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/s3-gateway-rs:1.2.8
   ```

**💡 Testing:** You can update the gateway env files and test this service immediately. Each service is independent and can be tested separately. See [Gateway: adempiere-ui-gateway](#gateway-adempiere-ui-gateway) section for env file update instructions.

---

## Service: dictionary-rs

**Status:** ⬜ Not started

**Docker Compose Service Name:** `dictionary-rs`
**Repository Name:** `dictionary_rs`

### Migration Details

- **Source Repository:** `https://github.com/adempiere/dictionary_rs` ✅ Already in adempiere org
- **Source Branch:** `main`
- **Target Repository:** `https://github.com/adempiere/dictionary_rs` (same - no fork needed)
- **Target Branch:** `main` (or create new branch for migration)
- **Current Docker Image:** `openls/dictionary-rs:1.5.5` (Docker Hub)
- **Target Docker Image:** `ghcr.io/adempiere/dictionary-rs:<version>` (GitHub Container Registry)

**Note:** This repository is already in the adempiere organization. Migration only requires changing the publishing destination from Docker Hub to ghcr.io.

### File 1: `.github/workflows/release.yaml`

#### Change 1: Docker Login - Add Registry
- **Location:** Lines 53-58 (the Docker login action block)
- **What to change:** Replace the `with:` section (lines 55-58 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Docker Image Tags
- **Location:** Lines 69-71 (the `tags:` section)
- **What to change:** Replace lines 70-71 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_HUB_REPO_NAME }}:${{ github.event.release.tag_name }}
  ${{ secrets.DOCKER_HUB_REPO_NAME }}
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/dictionary-rs:${{ github.event.release.tag_name }}
  ghcr.io/adempiere/dictionary-rs:latest
  ```

#### Change 3: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_HUB_REPO_NAME` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `1.6.4` (or chosen version per strategy - note: latest is 1.6.3)
   - Target: `main` branch
   - Title: "Dictionary RS v1.6.4 - Migration to ghcr.io"

2. **GitHub Actions Publishes Image**
   - Workflow: `.github/workflows/release.yaml` triggers automatically
   - Builds and publishes: `ghcr.io/adempiere/dictionary-rs:1.6.4`
   - Platforms: `linux/amd64`, `linux/amd64/v2`, `linux/arm64/v8`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/dictionary-rs:1.6.4
   ```

**💡 Testing:** You can update the gateway env files and test this service immediately. Each service is independent and can be tested separately. See [Gateway: adempiere-ui-gateway](#gateway-adempiere-ui-gateway) section for env file update instructions.

---

## Service: adempiere-report-engine

**Status:** ⬜ Not started

**Docker Compose Service Name:** `adempiere-report-engine`
**Repository Name:** `adempiere-report-engine-service`

### Migration Details

- **Source Repository:** `https://github.com/adempiere/adempiere-report-engine-service` ✅ Already in adempiere org
- **Source Branch:** `main`
- **Target Repository:** `https://github.com/adempiere/adempiere-report-engine-service` (same - no fork needed)
- **Target Branch:** `main` (or create new branch for migration)
- **Current Docker Images:** (Docker Hub)
  - `openls/adempiere-report-engine-service:alpine-1.3.7`
  - `openls/adempiere-report-engine-service:1.3.7` (ubuntu)
  - `openls/adempiere-grpc-proxy:1.3.7`
- **Target Docker Images:** (GitHub Container Registry)
  - `ghcr.io/adempiere/adempiere-report-engine-service:alpine-<version>`
  - `ghcr.io/adempiere/adempiere-report-engine-service:<version>` (ubuntu)
  - `ghcr.io/adempiere/adempiere-grpc-proxy:<version>`

**Note:** This repository is already in the adempiere organization and publishes **3 separate Docker images**. Migration requires changing the publishing destination from Docker Hub to ghcr.io.

### File 1: `.github/workflows/publish.yml`

#### Change 1: Docker Login - Alpine Image
- **Location:** Lines 152-157 (the Docker login action block for alpine image)
- **What to change:** Replace the `with:` section (lines 154-157 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Alpine Image Tags
- **Location:** Lines 171-175 (the `TAGS=` variable assignment section for alpine image)
- **What to change:** Replace all three TAGS lines that use `${{ secrets.DOCKER_HUB_REPO_NAME }}`
- **Find this:**
  ```yaml
  TAGS="${{ secrets.DOCKER_HUB_REPO_NAME }}:${{ github.event.release.tag_name }}-alpine"
  TAGS+=",${{ secrets.DOCKER_HUB_REPO_NAME }}:$CLEAN_BRANCH_NAME-alpine"
  ...
  TAGS+=",${{ secrets.DOCKER_HUB_REPO_NAME }}:alpine"
  ```
- **Replace with:**
  ```yaml
  TAGS="ghcr.io/adempiere/adempiere-report-engine-service:${{ github.event.release.tag_name }}-alpine"
  TAGS+=",ghcr.io/adempiere/adempiere-report-engine-service:$CLEAN_BRANCH_NAME-alpine"
  ...
  TAGS+=",ghcr.io/adempiere/adempiere-report-engine-service:alpine"
  ```

#### Change 3: Docker Login - Ubuntu Image
- **Location:** Lines 218-223 (the Docker login action block for ubuntu image)
- **What to change:** Replace the `with:` section (lines 220-223 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 4: Ubuntu Image Tags
- **Location:** Lines 237-241 (the `TAGS=` variable assignment section for ubuntu image)
- **What to change:** Replace all three TAGS lines that use `${{ secrets.DOCKER_HUB_REPO_NAME }}`
- **Find this:**
  ```yaml
  TAGS="${{ secrets.DOCKER_HUB_REPO_NAME }}:${{ github.event.release.tag_name }}"
  TAGS+=",${{ secrets.DOCKER_HUB_REPO_NAME }}:$CLEAN_BRANCH_NAME"
  ...
  TAGS+=",${{ secrets.DOCKER_HUB_REPO_NAME }}:latest"
  ```
- **Replace with:**
  ```yaml
  TAGS="ghcr.io/adempiere/adempiere-report-engine-service:${{ github.event.release.tag_name }}"
  TAGS+=",ghcr.io/adempiere/adempiere-report-engine-service:$CLEAN_BRANCH_NAME"
  ...
  TAGS+=",ghcr.io/adempiere/adempiere-report-engine-service:latest"
  ```

#### Change 5: Docker Login - gRPC Proxy Image
- **Location:** Lines 309-314 (the Docker login action block for gRPC proxy image)
- **What to change:** Replace the `with:` section (lines 311-314 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 6: gRPC Proxy Image Tags
- **Location:** Lines 328-332 (the `TAGS=` variable assignment section for gRPC proxy image)
- **What to change:** Replace all three TAGS lines that use `${{ secrets.DOCKER_HUB_PROXY_REPO_NAME }}`
- **Find this:**
  ```yaml
  TAGS="${{ secrets.DOCKER_HUB_PROXY_REPO_NAME }}:${{ github.event.release.tag_name }}"
  TAGS+=",${{ secrets.DOCKER_HUB_PROXY_REPO_NAME }}:$CLEAN_BRANCH_NAME"
  ...
  TAGS+=",${{ secrets.DOCKER_HUB_PROXY_REPO_NAME }}:latest"
  ```
- **Replace with:**
  ```yaml
  TAGS="ghcr.io/adempiere/adempiere-grpc-proxy:${{ github.event.release.tag_name }}"
  TAGS+=",ghcr.io/adempiere/adempiere-grpc-proxy:$CLEAN_BRANCH_NAME"
  ...
  TAGS+=",ghcr.io/adempiere/adempiere-grpc-proxy:latest"
  ```

#### Change 7: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_HUB_REPO_NAME` - used by old Docker Hub workflow
  - `DOCKER_HUB_PROXY_REPO_NAME` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `1.4.2` (or chosen version per strategy - note: latest is 1.4.1)
   - Target: `main` branch
   - Title: "ADempiere Report Engine v1.4.2 - Migration to ghcr.io"

2. **GitHub Actions Publishes 3 Images**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Publishes:
     - `ghcr.io/adempiere/adempiere-report-engine-service:1.4.2-alpine`
     - `ghcr.io/adempiere/adempiere-report-engine-service:1.4.2` (ubuntu multiplatform)
     - `ghcr.io/adempiere/adempiere-grpc-proxy:1.4.2`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-report-engine-service:1.4.2-alpine
   docker pull ghcr.io/adempiere/adempiere-report-engine-service:1.4.2
   docker pull ghcr.io/adempiere/adempiere-grpc-proxy:1.4.2
   ```

**💡 Testing:** You can update the gateway env files and test this service immediately. Each service is independent and can be tested separately. See [Gateway: adempiere-ui-gateway](#gateway-adempiere-ui-gateway) section for env file update instructions.

---

## Service: adempiere-site

**Status:** ⬜ Not started

**Docker Compose Service Name:** `adempiere-site`
**Repository Name:** `adempiere-landing-page`

### Migration Details

- **Source Repository:** `https://github.com/adempiere/adempiere-landing-page` ✅ Already in adempiere org
- **Source Branch:** `main`
- **Target Repository:** `https://github.com/adempiere/adempiere-landing-page` (same - no fork needed)
- **Target Branch:** `main`
- **Current Docker Image:** `openls/adempiere-landing-page:alpine-1.0.3` (env_template.env line 317: `ADEMPIERE_SITE_IMAGE`)
- **Target Docker Image:** `ghcr.io/adempiere/adempiere-landing-page:alpine-<version>` (GitHub Container Registry)
- **Local Clone:** `/data2/entwicklung/westfaliaRepository_2022-06/adempiere-landing-page_ADEMPIERE`
- **Current Version:** `1.0.3` (latest git tag)
- **Suggested Migration Version:** `1.0.4`

### Docker Publishing Workflow

**Current workflow:** `.github/workflows/publish.yaml`
- Builds VuePress site with pnpm
- Publishes to Docker Hub using `DOCKER_REPO_ADEMPIERE_LANDING_PAGE` secret (currently `openls/adempiere-landing-page`)
- Creates both alpine and multi-platform images
- Uses `build-docker/production-alpine.Dockerfile` and `build-docker/production.Dockerfile`

### Migration Steps

1. **Update Docker Registry in Workflow:**
   - Edit `.github/workflows/publish.yaml`
   - Change Docker Hub login to GitHub Container Registry (ghcr.io)
   - Update image tags from `${{ secrets.DOCKER_REPO_ADEMPIERE_LANDING_PAGE }}` to `ghcr.io/adempiere/adempiere-landing-page`
   - Configure GitHub secrets: `GHCR_USERNAME` and `GHCR_TOKEN`

2. **Create New Release:**
   - Tag: `1.0.4`
   - Verify: `docker pull ghcr.io/adempiere/adempiere-landing-page:alpine-1.0.4`

3. **Update Gateway Configuration:**
   - Edit `env_template.env` line 317
   - Change to: `ADEMPIERE_SITE_IMAGE="ghcr.io/adempiere/adempiere-landing-page:alpine-1.0.4"`

**💡 Testing:** You can update the gateway env files and test this service immediately. Each service is independent and can be tested separately. See [Gateway: adempiere-ui-gateway](#gateway-adempiere-ui-gateway) section for env file update instructions.

---

## Service: adempiere-zk (ZK UI)

**Status:** ⬜ Not started

**Docker Compose Service Name:** `adempiere-zk`
**Source Repository Name:** `adempiere-shw-zk`
**Target Repository Name:** `adempiere-zk`

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-shw-zk`
- **Source Branch:** `master`
- **Target Repository:** `https://github.com/adempiere/adempiere-zk` (fork and customize)
- **Target Branch:** TBD
- **Current Docker Image:** `marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.45`
- **Target Docker Image:** `ghcr.io/adempiere/adempiere-zk:jetty-<version>`

### File 1: `build.gradle`

#### Change 1: Maven Repository URL
- **Line:** 21
- **Before:** `url = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `url = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 21

#### Change 2: Customization Dependency (Comment as Stub)
- **Line:** 56
- **Before:** `implementation 'com.shw:adempiere-shw.shw_libs:'+ adempiereSHWRelease`
- **After:** `// implementation 'io.github.adempiere:adempiere-customizations.libs:'+ adempiereCustomizationsRelease`
- **Action:** Comment out line 56 and replace with stub reference

**Note:** Line 46 defines the version variable (`adempiereSHWRelease`). When uncommenting the stub, implementors should define `adempiereCustomizationsRelease` variable.

### File 2: `.github/workflows/publish.yml`

#### Change 1: Docker Login - Registry
- **Location:** Lines 102-107 (the Docker login action block)
- **What to change:** Replace the `with:` section (lines 104-107)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Docker Image Tags
- **Location:** Lines 115-117 (the `tags:` section)
- **What to change:** Replace lines 116-117 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_REPO_ADEMPIERE_ZK }}:jetty-${{ github.event.release.tag_name }}
  ${{ secrets.DOCKER_REPO_ADEMPIERE_ZK }}:jetty
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-zk:jetty-${{ github.event.release.tag_name }}
  ghcr.io/adempiere/adempiere-zk:jetty
  ```

#### Change 3: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_REPO_ADEMPIERE_ZK` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued. `GITHUB_TOKEN` is automatically available for the new workflow, no configuration needed.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `jetty-3.9.4.001-1.1.46` (or chosen version per strategy)
   - Target: Target branch (TBD)
   - Title: "ADempiere ZK v3.9.4.001-1.1.46 - Migration to adempiere"

2. **GitHub Actions Publishes Image**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Builds and publishes: `ghcr.io/adempiere/adempiere-zk:jetty-3.9.4.001-1.1.46`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-zk:jetty-3.9.4.001-1.1.46
   ```

**⚠️ Do NOT update gateway env files yet** - wait until all services have new versions published.

---

## Service: adempiere-processor

**Status:** ⬜ Not started

**Docker Compose Service Name:** `adempiere-processor`
**Repository Name:** `adempiere-processors-service`

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-processors-service`
- **Source Branch:** `feature/shw/customizations`
- **Target Repository:** `https://github.com/adempiere/adempiere-processors-service` (merge changes)
- **Target Branch:** TBD
- **Current Docker Image:** `marcalwestf/adempiere-processors-service:alpine-1.1.16`
- **Target Docker Image:** `ghcr.io/adempiere/adempiere-processors-service:alpine-<version>`

### File 1: `build.gradle`

#### Change 1: Maven Repository URL
- **Line:** 41
- **Before:** `url = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `url = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 41

#### Change 2: Customization Dependency (Comment as Stub)
- **Line:** 188
- **Before:** `implementation 'com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48'`
- **After:** `// implementation 'io.github.adempiere:adempiere-customizations.libs:3.9.4.001-<version>'`
- **Action:** Comment out line 188 and replace with stub reference

### File 2: `.github/workflows/publish.yml`

#### Change 1: Docker Login - Registry
- **Location:** Lines 175-178 (the Docker login action block)
- **What to change:** Replace the `with:` section and add registry line
- **Find this:**
  ```yaml
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Docker Image Tags
- **Location:** Lines 185-187 (the `tags:` section)
- **What to change:** Replace lines 186-187 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_HUB_REPO_NAME }}:alpine-${{ github.event.release.tag_name }}
  ${{ secrets.DOCKER_HUB_REPO_NAME }}:alpine
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-processors-service:alpine-${{ github.event.release.tag_name }}
  ghcr.io/adempiere/adempiere-processors-service:alpine
  ```


#### Change 3: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_HUB_REPO_NAME` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `alpine-1.1.17` (or chosen version per strategy)
   - Target: Target branch (TBD)
   - Title: "ADempiere Processors Service v1.1.17 - Migration to adempiere"

2. **GitHub Actions Publishes Image**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Builds and publishes: `ghcr.io/adempiere/adempiere-processors-service:alpine-1.1.17`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-processors-service:alpine-1.1.17
   ```

**⚠️ Do NOT update gateway env files yet** - wait until all services have new versions published.

---

## Service: adempiere-grpc-server

**Status:** ⬜ Not started

**Docker Compose Service Name:** `adempiere-grpc-server`
**Repository Name:** `adempiere-grpc-server`

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-grpc-server`
- **Source Branch:** `feature/shw/master`
- **Target Repository:** `https://github.com/adempiere/adempiere-grpc-server` (merge changes)
- **Target Branch:** TBD
- **Current Docker Image:** `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.30`
- **Target Docker Image:** `ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-<version>`

### File 1: `build.gradle`

#### Change 1: Maven Repository URL
- **Line:** 30
- **Before:** `url = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `url = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 30

#### Change 2: Customization Dependency (Comment as Stub)
- **Line:** 126
- **Before:** `implementation 'com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48'`
- **After:** `// implementation 'io.github.adempiere:adempiere-customizations.libs:3.9.4.001-<version>'`
- **Action:** Comment out line 126 and replace with stub reference

### File 2: `.github/workflows/publish.yml`

**Note:** This service publishes 3 Docker images: alpine, ubuntu multiplatform, and grpc-proxy.

#### Change 1: Docker Login - All Three Images
- **Location:** Three separate Docker login blocks (for alpine, ubuntu, and grpc-proxy images)
- **What to change:** In each Docker login block, replace the `with:` section to add registry and change credentials
- **Find this pattern (appears 3 times):**
  ```yaml
  with:
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with (in all 3 locations):**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```
- **Note:** Apply this change to all three Docker login actions in the workflow

#### Change 2: Docker Image Tags - Alpine
- **Location:** Alpine image tags section (around lines 170-171)
- **What to change:** Replace all tag lines that use `${{ secrets.DOCKER_REPO_ADEMPIERE_GRPC_SERVER }}` with hardcoded image name
- **Find this pattern:**
  ```yaml
  ${{ secrets.DOCKER_REPO_ADEMPIERE_GRPC_SERVER }}:alpine-${{ github.event.release.tag_name }}
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-grpc-server:alpine-${{ github.event.release.tag_name }}
  ```
- **Note:** Apply this replacement pattern to all alpine image tags in this section

#### Change 3: Docker Image Tags - Ubuntu Multiplatform
- **Location:** Ubuntu multiplatform image tags section (around lines 212-213)
- **What to change:** Replace all tag lines that use `${{ secrets.DOCKER_REPO_ADEMPIERE_GRPC_SERVER }}` with hardcoded image name
- **Find this pattern:**
  ```yaml
  ${{ secrets.DOCKER_REPO_ADEMPIERE_GRPC_SERVER }}:<tag>
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-grpc-server:<tag>
  ```
- **Note:** Apply this replacement pattern to all ubuntu image tags in this section

#### Change 4: Docker Image Tags - gRPC Proxy
- **Location:** gRPC proxy image tags section (around lines 274-275)
- **What to change:** Replace all tag lines that use secrets with hardcoded image name
- **Find this pattern:**
  ```yaml
  <secret>:grpc-proxy-<tag>
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-grpc-server:grpc-proxy-<tag>
  ```
- **Note:** Apply this replacement pattern to all grpc-proxy image tags in this section

#### Change 5: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_REPO_ADEMPIERE_GRPC_SERVER` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `3.9.4.001-1.0.31` (or chosen version per strategy)
   - Target: Target branch (TBD)
   - Title: "ADempiere gRPC Server v3.9.4.001-1.0.31 - Migration to adempiere"

2. **GitHub Actions Publishes Images**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Publishes **3 images**:
     - `ghcr.io/adempiere/adempiere-grpc-server:alpine-3.9.4.001-1.0.31`
     - `ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-1.0.31` (ubuntu multiplatform)
     - `ghcr.io/adempiere/adempiere-grpc-server:grpc-proxy-<version>`

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-1.0.31
   ```

**⚠️ Do NOT update gateway env files yet** - wait until all services have new versions published.

---

## Service: vue-ui (Vue UI)

**Status:** ⬜ Not started

**Docker Compose Service Name:** `vue-ui`
**Repository Name:** `adempiere-vue`

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-vue`
- **Source Branch:** `develop`
- **Target Repository:** `https://github.com/adempiere/adempiere-vue` (merge changes)
- **Target Branch:** TBD
- **Current Docker Image:** `marcalwestf/adempiere-vue:0.0.5`
- **Target Docker Image:** `ghcr.io/adempiere/adempiere-vue:<version>`

**Note:** This is a Node.js/Vue.js project (uses `package.json`, not `build.gradle`). No Maven dependencies to change.

### File 1: `.github/workflows/publish.yml`

#### Change 1: Docker Login - Alpine Image
- **Location:** Lines 128-133 (the Docker login action block for alpine image)
- **What to change:** Replace the `with:` section (lines 130-133 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 2: Docker Login - Multiplatform Image
- **Location:** Lines 166-171 (the Docker login action block for multiplatform image)
- **What to change:** Replace the `with:` section (lines 168-171 within this block)
- **Find this:**
  ```yaml
  with:
    # CONFIGURE DOCKER SECRETS INTO REPOSITORY
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_TOKEN }}
  ```
- **Replace with:**
  ```yaml
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
  ```

#### Change 3: Docker Image Tags - Alpine
- **Location:** Lines 141-143 (the `tags:` section for alpine image)
- **What to change:** Replace lines 142-143 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_REPO_FRONTEND }}:alpine
  ${{ secrets.DOCKER_REPO_FRONTEND }}:alpine-${{ github.event.release.tag_name }}
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-vue:alpine
  ghcr.io/adempiere/adempiere-vue:alpine-${{ github.event.release.tag_name }}
  ```

#### Change 4: Docker Image Tags - Multiplatform
- **Location:** Lines 180-182 (the `tags:` section for multiplatform image)
- **What to change:** Replace lines 181-182 (the two tag lines under `tags: |`)
- **Find this:**
  ```yaml
  ${{ secrets.DOCKER_REPO_FRONTEND }}:latest
  ${{ secrets.DOCKER_REPO_FRONTEND }}:${{ github.event.release.tag_name }}
  ```
- **Replace with:**
  ```yaml
  ghcr.io/adempiere/adempiere-vue:latest
  ghcr.io/adempiere/adempiere-vue:${{ github.event.release.tag_name }}
  ```

#### Change 5: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DOCKER_USERNAME` - used by old Docker Hub workflow
  - `DOCKER_TOKEN` - used by old Docker Hub workflow
  - `DOCKER_REPO_FRONTEND` - used by old Docker Hub workflow
- **Note:** These secrets are no longer used by the new ghcr.io workflow, but keep them until migration is fully tested. Consider deleting them later if Docker Hub publishing is permanently discontinued.

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `0.0.6` (or chosen version per strategy)
   - Target: Target branch (TBD)
   - Title: "ADempiere Vue v0.0.6 - Migration to adempiere"

2. **GitHub Actions Publishes Images**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Publishes **2 images**:
     - `ghcr.io/adempiere/adempiere-vue:alpine-0.0.6`
     - `ghcr.io/adempiere/adempiere-vue:0.0.6` (multiplatform)
   - Also publishes `ghcr.io/adempiere/adempiere-vue:latest` tag

3. **Verify Publication**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-vue:0.0.6
   ```

**⚠️ Do NOT update gateway env files yet** - wait until all services have new versions published.

---

## Library: adempiere-shw (Customization Library)

**Status:** ⬜ Not started

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-shw`
- **Source Branch:** `main`
- **Target Repository:** `https://github.com/adempiere/adempiere-customizations` (generic template)
- **Target Branch:** TBD
- **Current Maven Artifact:** `com.shw:adempiere-shw.shw_libs:3.9.4.001-1.1.48`
- **Target Maven Artifact:** `io.github.adempiere:adempiere-customizations.libs:<version>` (as stub)

**Special Handling:** This repository should be migrated as a **generic template** with customization stubs, not with SHW-specific implementations.

### File 1: `build.gradle` (root)

#### Change 1: Maven Repository URL (Self-Reference)
- **Line:** 9
- **Before:** `url = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `url = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 9

#### Change 2: libraryRepo Variable
- **Line:** 33
- **Before:** `libraryRepo = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `libraryRepo = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 33

#### Change 3: publishGroupId Variable
- **Line:** 37
- **Before:** `publishGroupId = "com.shw"`
- **After:** `publishGroupId = "io.github.adempiere"`
- **Action:** Edit line 37

#### Change 4: Maven Publication groupId
- **Line:** 101
- **Before:** `groupId = publishGroupId` (results in `com.shw`)
- **After:** `groupId = publishGroupId` (results in `io.github.adempiere`)
- **Action:** Verify correct after line 37 change

#### Change 5: Maven Publication artifactId
- **Line:** 102
- **Before:** `artifactId = 'adempiere-shw'`
- **After:** `artifactId = 'adempiere-customizations'`
- **Action:** Edit line 102

### File 2: `shw_libs/build.gradle`

#### Change 1: Maven Repository URL (Self-Reference)
- **Line:** 17
- **Before:** `url = "https://maven.pkg.github.com/Systemhaus-Westfalia/adempiere-shw"`
- **After:** `url = "https://maven.pkg.github.com/adempiere/adempiere-customizations"`
- **Action:** Edit line 17

#### Change 2: lsv-general Customization Dependency (Comment as Stub)
- **Line:** 161
- **Before:** `api "com.shw:lsv-general:1.0.41"`
- **After:** `// api "your.organization:your-customization-library:<version>"`
- **Action:** Comment out line 161 and replace with generic stub

**Documentation Note:** Add comment explaining that implementors should:
1. Create their own customization repository
2. Publish it to their Maven repository
3. Uncomment and modify this line with their artifact coordinates

#### Change 3: Maven Publication groupId
- **Line:** 198
- **Before:** `groupId = 'com.shw'`
- **After:** `groupId = 'io.github.adempiere'`
- **Action:** Edit line 198

#### Change 4: Maven Publication artifactId
- **Line:** 199
- **Before:** `artifactId = 'adempiere-shw.' + packageName`
- **After:** `artifactId = 'adempiere-customizations.' + packageName`
- **Action:** Edit line 199

### File 3: `.github/workflows/publish.yml`

**Note:** This workflow publishes Maven artifacts, NOT Docker images.

#### Change 1: Maven Credentials - Secrets
- **Lines:** 37-38
- **Before:**
  ```yaml
  ORG_GRADLE_PROJECT_deployUsername: ${{ secrets.DEPLOY_USER }}
  ORG_GRADLE_PROJECT_deployToken: ${{ secrets.DEPLOY_TOKEN }}
  ```
- **After:**
  ```yaml
  ORG_GRADLE_PROJECT_deployUsername: ${{ github.actor }}
  ORG_GRADLE_PROJECT_deployToken: ${{ secrets.GITHUB_TOKEN }}
  ```
- **Action:** Edit lines 37-38

#### Change 2: Repository Secrets (GitHub UI)
- **Action:** Keep existing secrets for now (no changes needed)
  - `DEPLOY_USER` - used by old Maven publishing workflow
  - `DEPLOY_TOKEN` - used by old Maven publishing workflow
- **Note:** These secrets are no longer used by the new GitHub Packages workflow (which uses `GITHUB_TOKEN`), but keep them until migration is fully tested. Consider deleting them later if the old Maven publishing is permanently discontinued.

#### Change 3: Publishing Destination
- **Verification:** The `libraryRepo` variable in `build.gradle` (line 33) controls where artifacts are published
- **Action:** Verify that after build.gradle changes, artifacts will publish to `maven.pkg.github.com/adempiere/adempiere-customizations`

### Release Creation

After all code changes are committed:

1. **Create GitHub Release**
   - Tag: `3.9.4.001-1.1.49` (or chosen version per strategy)
   - Target: Target branch (TBD)
   - Title: "ADempiere Customizations v3.9.4.001-1.1.49 - Generic Template"

2. **GitHub Actions Publishes Maven Artifacts**
   - Workflow: `.github/workflows/publish.yml` triggers automatically
   - Publishes to: `maven.pkg.github.com/adempiere/adempiere-customizations`
   - Artifacts:
     - `io.github.adempiere:adempiere-customizations:3.9.4.001-1.1.49`
     - `io.github.adempiere:adempiere-customizations.libs:3.9.4.001-1.1.49`

3. **Verify Publication**
   - Navigate to: `https://github.com/adempiere/adempiere-customizations/packages`
   - Verify packages are listed and accessible

**Note:** This library is a **generic template**. Containerized services will have customization dependencies **commented out as stubs**, so this library is optional for basic deployment.

**⚠️ Do NOT update containerized service dependencies** - they should remain commented as stubs in the generic adempiere repositories.

---

## Gateway: adempiere-ui-gateway

**Status:** ⬜ Not started

### Migration Details

- **Source Repository:** `https://github.com/Systemhaus-Westfalia/adempiere-ui-gateway`
- **Source Branch:** `adempiere-trunk`
- **Target Repository:** `https://github.com/adempiere/adempiere-ui-gateway`
- **Target Branch:** TBD
- **Purpose:** Main orchestration stack that references all containerized services

---

**⚠️ CRITICAL TIMING:** This step must be done **LAST**, after all 8 containerized services have:
1. Completed code migrations
2. Had releases created
3. Published new Docker images to `ghcr.io/adempiere/`
4. Been verified with `docker pull`

The env files reference specific version tags. Those versions must exist before you update these files.

---

### File 1: `docker-compose/env_template.env`

#### Change 1: ZK UI Image
- **Line:** 130
- **Before:** `ADEMPIERE_ZK_IMAGE="marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.45"`
- **After:** `ADEMPIERE_ZK_IMAGE="ghcr.io/adempiere/adempiere-zk:jetty-<version>"`
- **Action:** Edit line 130

#### Change 2: Processors Service Image
- **Line:** 151
- **Before:** `ADEMPIERE_PROCESSOR_IMAGE="marcalwestf/adempiere-processors-service:alpine-1.1.16"`
- **After:** `ADEMPIERE_PROCESSOR_IMAGE="ghcr.io/adempiere/adempiere-processors-service:alpine-<version>"`
- **Action:** Edit line 151

#### Change 3: gRPC Server Image
- **Line:** 233
- **Before:** `VUE_BACKEND_GRPC_SERVER_IMAGE="marcalwestf/adempiere-grpc-server:3.9.4.001-shw-${VUE_BACKEND_GRPC_SERVER_VERSION}"`
- **After:** `VUE_BACKEND_GRPC_SERVER_IMAGE="ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-${VUE_BACKEND_GRPC_SERVER_VERSION}"`
- **Action:** Edit line 233

#### Change 4: Vue UI Image
- **Line:** 290
- **Before:** `VUE_UI_IMAGE="marcalwestf/adempiere-vue:0.0.5"`
- **After:** `VUE_UI_IMAGE="ghcr.io/adempiere/adempiere-vue:<version>"`
- **Action:** Edit line 290

#### Change 5: S3 Gateway Image
- **Line:** 117
- **Before:** `S3_GATEWAY_RS_IMAGE="openls/s3-gateway-rs:1.2.7"`
- **After:** `S3_GATEWAY_RS_IMAGE="ghcr.io/adempiere/s3-gateway-rs:<version>"`
- **Action:** Edit line 117

#### Change 6: Dictionary Service Image
- **Line:** 221
- **Before:** `DICTIONARY_RS_IMAGE="openls/dictionary-rs:1.5.5"`
- **After:** `DICTIONARY_RS_IMAGE="ghcr.io/adempiere/dictionary-rs:<version>"`
- **Action:** Edit line 221

#### Change 7: Report Engine Service Image
- **Line:** 248
- **Before:** `VUE_REPORT_GRPC_SERVER_IMAGE="openls/adempiere-report-engine-service:alpine-1.3.7"`
- **After:** `VUE_REPORT_GRPC_SERVER_IMAGE="ghcr.io/adempiere/adempiere-report-engine-service:alpine-<version>"`
- **Action:** Edit line 248

#### Change 8: Landing Page Service Image
- **Line:** 317
- **Before:** `ADEMPIERE_SITE_IMAGE="openls/adempiere-landing-page:alpine-1.0.3"`
- **After:** `ADEMPIERE_SITE_IMAGE="ghcr.io/adempiere/adempiere-landing-page:alpine-<version>"`
- **Action:** Edit line 317

#### Change 9: Sync to .env File
- **After all env_template.env changes:**
- **Action:** Copy all image reference changes from `env_template.env` to `.env`
- **Verification:** Both files should have identical image references

### File 2: `CLAUDE.md`

#### Update Repository References
- **Section:** "Branch Information"
- **Before:** References to Systemhaus-Westfalia forks and temporary namespaces
- **After:** Update all repository references to point to `adempiere` organization
- **Action:** Search for "Systemhaus-Westfalia", "marcalwestf", "openls" and update documentation

### File 3: `.claude-memory/migration-plan.md`

#### Mark Migration Complete
- **Action:** Update status from "📝 Draft" to "✅ Completed"
- **Action:** Add migration completion date
- **Action:** Document any deviations from the plan

### File 4: Documentation (`docs/` directory)

#### Update All Service References
- **Files:** All markdown files in `docs/` directory
- **Action:** Search and replace:
  - `marcalwestf/` → `ghcr.io/adempiere/`
  - `openls/` → `ghcr.io/adempiere/`
  - Repository URLs from Systemhaus-Westfalia to adempiere
- **Specific files to check:**
  - `docs/services.md` - service descriptions and image references
  - `docs/architecture.md` - architecture diagrams and component references
  - `docs/installation.md` - installation instructions
  - `docs/quickstart.md` - quick start examples

---

## Execution Order Recommendation

The migration should follow this sequence to minimize dependencies. **Each service must complete ALL steps (code changes, commit, release creation, image publication, verification) before moving to the next service.**

**Note:** The service numbers below (Service 1, Service 2, etc.) indicate the **recommended migration sequence**, starting with simpler migrations and progressing to more complex ones.

### Phase 1: Foundation (Customization Library)

**Service 1: adempiere-shw → adempiere-customizations**
- **Reason:** All containerized services depend on this library
- **Steps:**
  1. Make code changes (build.gradle, publish.yml)
  2. Commit to target branch
  3. Create release (tag: `3.9.4.001-1.1.49`)
  4. GitHub Actions publishes Maven artifacts
  5. Verify at `github.com/adempiere/adempiere-customizations/packages`
- **Output:** Generic customization template available

### Phase 2: Simple Migrations (openls - Already in adempiere org)

These services only require workflow updates (Docker Hub → ghcr.io). Start with these to build confidence.

For each service below, follow this workflow:
- Update `.github/workflows/publish.yml` → Commit → Create release → Verify publication

**Service 2: s3-gateway-rs**
- Release tag: `1.2.8`
- Verify: `docker pull ghcr.io/adempiere/s3-gateway-rs:1.2.8`

**Service 3: dictionary-rs**
- Release tag: `1.6.4`
- Verify: `docker pull ghcr.io/adempiere/dictionary-rs:1.6.4`

**Service 4: adempiere-report-engine-service**
- Release tag: `1.4.2`
- Verify: `docker pull ghcr.io/adempiere/adempiere-report-engine-service:1.4.2`

**Service 5: adempiere-site**
- Release tag: `alpine-1.0.4`
- Verify: `docker pull ghcr.io/adempiere/adempiere-landing-page:alpine-1.0.4`

### Phase 3: Complex Migrations (marcalwestf - Require Repository Forks)

These services require forking repositories and merging code before workflow updates.

For each service below, follow this workflow:
- Fork/merge repository → Update workflows → Commit → Create release → Verify publication

**Service 6: adempiere-shw-zk → adempiere-zk**
- Release tag: `jetty-3.9.4.001-1.1.46`
- Verify: `docker pull ghcr.io/adempiere/adempiere-zk:jetty-3.9.4.001-1.1.46`

**Service 7: adempiere-processors-service**
- Release tag: `alpine-1.1.17`
- Verify: `docker pull ghcr.io/adempiere/adempiere-processors-service:alpine-1.1.17`

**Service 8: adempiere-grpc-server**
- Release tag: `3.9.4.001-1.0.31`
- Verify: `docker pull ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-1.0.31`

**Service 9: adempiere-vue**
- Release tag: `0.0.6`
- Verify: `docker pull ghcr.io/adempiere/adempiere-vue:0.0.6`

### Phase 4: Gateway Orchestration (VERSION REFERENCES)

**⚠️ CRITICAL:** Do NOT start this phase until ALL 8 containerized services (both openls and marcalwestf groups) have published Docker images to ghcr.io.

**Service 10: adempiere-ui-gateway**
- **Action:** Update `env_template.env` with all new image references
- **Steps:**
  1. Update line 130: ZK image → `ghcr.io/adempiere/adempiere-zk:jetty-3.9.4.001-1.1.46`
  2. Update line 151: Processors → `ghcr.io/adempiere/adempiere-processors-service:alpine-1.1.17`
  3. Update line 233: gRPC server → `ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-1.0.31`
  4. Update line 290: Vue UI → `ghcr.io/adempiere/adempiere-vue:0.0.6`
  5. Update line 117: S3 gateway → `ghcr.io/adempiere/s3-gateway-rs:1.2.8`
  6. Update line 221: Dictionary → `ghcr.io/adempiere/dictionary-rs:1.6.4`
  7. Update line 248: Report engine → `ghcr.io/adempiere/adempiere-report-engine-service:alpine-1.4.2`
  8. Update line 317: Landing page → `ghcr.io/adempiere/adempiere-landing-page:alpine-1.0.4`
  9. Copy all changes from `env_template.env` to `.env`
  10. Update documentation (CLAUDE.md, docs/*.md)
  11. Commit all changes

### Phase 5: Full Stack Verification

**Prerequisites:** All services migrated, gateway env files updated.

1. **Pull All Images**
   ```bash
   docker pull ghcr.io/adempiere/adempiere-zk:jetty-3.9.4.001-1.1.46
   docker pull ghcr.io/adempiere/adempiere-processors-service:alpine-1.1.17
   docker pull ghcr.io/adempiere/adempiere-grpc-server:3.9.4.001-1.0.31
   docker pull ghcr.io/adempiere/adempiere-vue:0.0.6
   docker pull ghcr.io/adempiere/s3-gateway-rs:1.2.8
   docker pull ghcr.io/adempiere/dictionary-rs:1.6.4
   docker pull ghcr.io/adempiere/adempiere-report-engine-service:alpine-1.4.2
   docker pull ghcr.io/adempiere/adempiere-landing-page:alpine-1.0.4
   ```

2. **Start Stack**
   ```bash
   cd docker-compose/
   ./start-all.sh -d default
   ```

3. **Verify Services**
   - ZK UI: `http://<HOST_IP>/webui`
   - Vue UI: `http://<HOST_IP>/vue`
   - API: `http://<HOST_IP>/api/`
   - Landing page: `http://<HOST_IP>/`
   - Check container logs for errors
   - Test database operations
   - Test S3 storage
   - Test dictionary cache

4. **Verify Integration**
   - Login to ZK UI
   - Login to Vue UI
   - Test POS operations (if applicable)
   - Run reports
   - Test gRPC API endpoints

5. **Document Results**
   - Update `.claude-memory/migration-plan.md` status to "✅ Completed"
   - Note any issues or deviations
   - Document actual versions used

---

## Verification Checklist

After completing migration for each service:

### Code Changes
- [ ] Source code forked/created in correct `adempiere` organization repository
- [ ] Target branch created and configured
- [ ] GitHub Actions workflow modified (Docker Hub → ghcr.io)
- [ ] Repository secrets deleted (DOCKER_USERNAME, DOCKER_TOKEN, etc.)
- [ ] Maven dependencies updated (com.shw → io.github.adempiere or commented as stubs)
- [ ] Maven repository URLs updated (Systemhaus-Westfalia → adempiere)
- [ ] All changes committed to target branch

### Release & Publication
- [ ] Version tag decided per versioning strategy
- [ ] GitHub Release created with appropriate tag
- [ ] GitHub Actions workflow completed successfully
- [ ] Docker image published to `ghcr.io/adempiere/<service-name>:<tag>` (or Maven artifact)
- [ ] Publication verified: `docker pull ghcr.io/adempiere/<service-name>:<tag>`
- [ ] Image/artifact accessible and functional

### Gateway Integration (Phase 4 Only)
- [ ] All 8 containerized services have published new versions
- [ ] `adempiere-ui-gateway` env_template.env updated with new image references
- [ ] `adempiere-ui-gateway` .env updated (synced with env_template.env)
- [ ] Documentation updated (CLAUDE.md, docs/*.md)
- [ ] Gateway changes committed

### Full Stack Testing (Phase 5 Only)
- [ ] All new images pulled successfully
- [ ] Stack starts without errors
- [ ] ZK UI accessible and functional
- [ ] Vue UI accessible and functional
- [ ] API endpoints responding
- [ ] Database operations working
- [ ] S3 storage accessible
- [ ] Dictionary cache functioning
- [ ] No errors in container logs
- [ ] Migration plan marked as complete

---

## Notes for Implementors (Customizations)

This migration creates a **generic template stack** at `adempiere` organization. Organizations that need customizations should:

1. **Fork adempiere-customizations:**
   - Fork `https://github.com/adempiere/adempiere-customizations`
   - Rename to `your-organization-customizations`
   - Uncomment and modify the stub at `shw_libs/build.gradle` line 161
   - Add your custom Maven dependency (your custom libraries)

2. **Update Service Dependencies:**
   - In your forks of containerized services (ZK, gRPC, Processors):
   - Uncomment the customization dependency stubs
   - Reference your customization library artifact
   - Example: `implementation 'com.yourorg:yourorg-customizations.libs:<version>'`

3. **Publish Your Customization Library:**
   - Configure GitHub Packages or your Maven repository
   - Publish your customization artifact
   - Update service build files to reference your Maven repository

4. **Maintain Your Stack:**
   - Keep your forks updated with upstream `adempiere` changes
   - Merge upstream updates into your customization branches
   - Re-publish your custom Docker images as needed

---

## Appendix: Common Issues and Solutions

### Issue 1: Maven Authentication Failed
**Symptom:** Build fails with "401 Unauthorized" when accessing `maven.pkg.github.com`
**Solution:** Ensure `GITHUB_TOKEN` has `read:packages` and `write:packages` permissions

### Issue 2: Docker Image Pull Failed
**Symptom:** `docker pull` fails with "unauthorized" or "not found"
**Solution:**
- Verify image name: `ghcr.io/adempiere/<service-name>:<tag>`
- Ensure repository visibility is public or authenticate: `docker login ghcr.io`
- Check that GitHub Actions workflow successfully published the image

### Issue 3: Customization Dependency Not Found
**Symptom:** Build fails with "Could not find com.shw:adempiere-shw.shw_libs"
**Solution:**
- The dependency should be commented out as a stub after migration
- If uncommenting, ensure your customization library is published and accessible

### Issue 4: Service Won't Start After Migration
**Symptom:** Container exits immediately or fails health checks
**Solution:**
- Check container logs: `docker logs <container-name>`
- Verify image tag matches published version
- Ensure environment variables are correct in env_template.env and .env

---

## Document Maintenance

**Owner:** Migration Team
**Review Frequency:** After each service migration
**Update Trigger:** When line numbers change, new services added, or migration approach modified
