# Team Shared Memory

This directory contains **collaboration context** for working with Claude Code on this repository. It is version-controlled so all team members share the same context.

## Purpose

Session history and team notes that help Claude Code pick up where the last session left off — without repeating solved problems or losing context.

## Files

- **recent-work.md** — Current state of the stack and what was last done
- **learned-patterns.md** — Claude Code session startup protocol and collaboration notes

## What does NOT belong here

- Project documentation → `docs/*.md`
- Architecture, services, installation, troubleshooting → `docs/*.md`
- Migration planning and status → `/home/westfalia/Westfalia-Projekte/Westfalia/Lieferanten/04-Claude/04-Claude-Cases/`

## When to Update

After completing work, ask Claude:
```
Please update .claude-memory/recent-work.md with what we did today
```

Then commit and push:
```bash
git add .claude-memory/
git commit -m "Update team memory: [brief description]"
git push
```

## Before Starting Work

```bash
git pull
cat .claude-memory/recent-work.md
```
