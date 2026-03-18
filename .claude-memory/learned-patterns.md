# Claude Code Session Notes

## Session Startup Protocol

At the START of every session, Claude should:
1. Check if `.claude-memory/` exists and read ALL files in it
2. Read `recent-work.md` for current stack state and last completed work
3. Check `known-issues.md` for any active blockers

This prevents repeating solved problems and maintains continuity across sessions and machines.

## Collaboration Notes

- User commits manually — do not auto-commit
- No backup files in git projects — use `git stash` or `git diff` instead of `.backup` copies
- Test on Mini PC (192.168.1.12) first, then apply locally and commit
- Migration planning documents live in `/home/westfalia/Westfalia-Projekte/Westfalia/Lieferanten/04-Claude/04-Claude-Cases/` — not in this repo
