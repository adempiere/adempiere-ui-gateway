# Team Shared Memory

This directory contains shared knowledge and context across team members working on the ADempiere UI Gateway repository.

## Purpose

Since Claude Code conversation history is local to each machine, this directory serves as **version-controlled shared memory** that all team members can access and update.

## Files

- **recent-work.md** - Latest changes, ongoing work, and current context
- **known-issues.md** - Bugs, gotchas, workarounds, and debugging tips
- **learned-patterns.md** - Best practices, tips for Docker Compose, ADempiere, nginx configuration

## When to Update

Update these files after:
- Solving a non-trivial Docker/networking problem
- Discovering database restore quirks or container startup issues
- Making significant changes to stack configuration
- Finding workarounds for nginx/proxy issues
- Learning something about ADempiere deployment that would help the next person
- Modifying service definitions or stack compositions

## How to Update

After completing work, ask Claude:
```
Please update .claude-memory/[relevant-file].md with what we learned/changed today
```

Then commit and push:
```bash
git add .claude-memory/
git commit -m "Update team memory: [brief description]"
git push
```

## Before Starting Work

Always pull latest and check these files for recent team context:
```bash
git pull
cat .claude-memory/recent-work.md
```
