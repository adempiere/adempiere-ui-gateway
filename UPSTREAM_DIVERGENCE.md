# Upstream divergence analysis — adempiere-trunk vs. adempiere/adempiere-ui-gateway:main

**Analyzed:** 2026-06-16
**Purpose:** Document the relationship between this fork's `adempiere-trunk` branch and the
upstream `adempiere/adempiere-ui-gateway:main` branch before the migration PR (Phase 4 of the
Systemhaus-Westfalia → adempiere org migration).

---

## Fork origin

`Systemhaus-Westfalia/adempiere-ui-gateway` is a GitHub fork of `adempiere/adempiere-ui-gateway`,
created 2024-02-20.

## Common ancestor

```
git merge-base adempiere-trunk upstream/main
6ff102eb0b141655c9ad3beb73447cb25b98b076  "Update README.md: typo"
```

This commit is also the current HEAD of `upstream/main` — meaning **`upstream/main` is fully
contained as an ancestor of `adempiere-trunk`**. The community's `main` branch (including all
commits up to and beyond the `1.2.5` release tag) was already absorbed into `adempiere-trunk`
at some point; there is no upstream work that is missing here.

## Divergence summary

```
git rev-list --left-right --count adempiere-trunk...upstream/main
324  0
```

- 324 commits ahead (SHW-only work)
- 0 commits behind (nothing on upstream/main is missing)
- 130 file changes vs. upstream/main (52 added, 51 deleted, 15 modified, plus several renames)

**Test merge result:** `git merge upstream/main --no-commit --no-ff` on a throwaway branch
reported "Already up to date" — **zero conflicts**, since upstream/main is already an ancestor.

## SHW-specific features and rationale

The 324 commits represent substantial restructuring and hardening work, not just config
tweaks:

- **Docker Compose consolidation** — collapsed ~35 modular per-service compose files
  (`01a-postgres_service...yml` through `19a-opensearch_dashboards...yml`, plus profile
  variants like `docker-compose-develop.yml`, `docker-compose-standard.yml`) into a single
  `docker-compose.yml`. Simpler to read and maintain; no functional loss identified.
- **Nginx consolidation** — collapsed deeply nested per-endpoint conf files
  (`nginx/api/backend/*.conf`, `nginx/api/dictionary_rs/*.conf`, `nginx/api/s3/*.conf`, etc.)
  into one conf file per backend service (`adempiere_backend.conf`, `adempiere_vue.conf`,
  `adempiere_zk.conf`, `dictionary_rs.conf`, `s3_gateway_rs.conf`, ...).
- **Env file tooling** — `env_template.env` + new `override_template.env`,
  `generate-env.sh` / `generate_env.py` for guided env generation, `health-check.sh` for
  verifying all services from the CLI.
- **Lifecycle scripts** — `start-all.sh`, `stop-all.sh`, `stop-and-delete-all.sh` for full
  stack control.
- **Extensive `docs/` folder** — architecture diagrams (`.excalidraw`/`.png`/`.svg` per
  service), `installation.md`, `quickstart.md`, `debugging*.md`, `troubleshooting.md`,
  `security.md`, `backup-restore.md`, `profiles.md`, `system-requirements.md`,
  `remote-access.md`, plus helper scripts under `docs/scripts/`. None of this exists upstream.
- **Keycloak and OpenSearch integration** — realm configs and setup scripts, already present
  before this migration (confirmed superseded content from the old `feature/shw_improvements`
  branch — see below).

This matches the "What changes vs what stays" table in `08-adempiere-ui-gateway.md`: the
restructuring is intentional SHW work to be carried into the migration (minus the
SHW-specific/El-Salvador content called out separately in Steps 4–6).

## Relationship to the old `feature/shw_improvements` branch

`adempiere/adempiere-ui-gateway` already had a `feature/shw_improvements` branch (renamed to
`feature/shw_improvements_LEGACY` in Step 1 of the migration, 2026-06-16). That branch's last
commit is from 2024-02-21 — one day after the fork was created. It represents an early,
since-superseded attempt at this same migration: comparing it against the current
`adempiere-trunk` shows everything it touched (keycloak configs, opensearch services,
start/stop scripts, early nginx restructuring) already exists in `adempiere-trunk` in a more
developed form. **Nothing from that branch needs to be cherry-picked.**

## Conflict resolution policy

SHW content takes precedence over upstream. In practice this analysis found no actual
conflicts to resolve — `adempiere-trunk` is a strict superset of `upstream/main` plus 324
SHW commits layered cleanly on top.
