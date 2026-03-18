# Recent Work

## Current Stack State (as of 2026-03-18)

**Mini PC (192.168.1.12) — stable, all services working**
- Branch: `adempiere-trunk`, tag `20260312/adempiere-trunk-latest-working`
- `marcalwestf/adempiere-grpc-server:3.9.4.001-shw-1.0.34`
- `marcalwestf/adempiere-processors-service:alpine-1.1.18`
- `marcalwestf/adempiere-shw-zk:jetty-3.9.4.001-shw-1.1.48`
- `marcalwestf/adempiere-vue:0.0.8`
- `ghcr.io/adempiere/dictionary-rs:1.6.5`
- Vue menu: ✅ working — ZK UI: ✅ working — POS payment: ✅ working

**Local repo (`adempiere-ui-gateway_SHW`) — branch `adempiere-trunk`**
- `env_template.env` matches Mini PC image versions above
- Documentation overhaul in progress (session 2026-03-18)

## Last Session (2026-03-18)

- Deleted `CLAUDE.md` and distributed its content to `docs/`
- Updated `docs/architecture.md`: added health check timeout table, fixed image versions, removed outdated fragment-assembly sections (Stack Assembly Logic, Service Naming Convention, Deployment-Specific Configuration)
- Updated `docs/services.md`: corrected all 14 image versions and registries
- Updated `docs/installation.md`: fixed heading hierarchy (`#####` → `####`), numbered top-level sections, switched Manual Execution steps to letters
- Updated `docs/docker-images.md`: current versions, correct registries (`openls/*` → `ghcr.io/adempiere/*`)
- Updated `docs/debugging.md`: added three-step gRPC service update checklist (envoy proto descriptor pattern)
- Updated `docs/troubleshooting.md`: added "Vue Menu Empty After Database Restore" runbook (6-step procedure), added "Container Configuration Issues" section (wrong prefix, postgres_database permissions), updated TOC
- Cleaned `.claude-memory/`: deleted `migration-plan.md`, `migration-steps-detailed.md`, `test-log.md`, `known-issues.md`; stripped `learned-patterns.md` and `recent-work.md` to collaboration-only content; updated `README.md`

## Next Steps

- Functional testing on Mini PC (user will advise what to test)
- Migration of `Systemhaus-Westfalia/adempiere-shw` → `adempiere/adempiere-customizations`
  (see plan: `/home/westfalia/Westfalia-Projekte/Westfalia/Lieferanten/04-Claude/04-Claude-Cases/20260317-aktualisierte_Migration/02-Migration_Plan.md`)
