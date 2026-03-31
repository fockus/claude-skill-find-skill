# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code **skill** (`find-skill`) that searches, recommends, and installs other Claude Code skills from multiple community and official sources. It maintains a local JSON catalogue that auto-updates monthly via cron.

## Key Files

- `SKILL.md` — Skill definition and prompt (the instructions Claude follows when the skill is invoked)
- `update-skills-catalogue.sh` — Shell script that fetches skills from 12 sources (Anthropic, ComposioHQ, vercel-labs, VoltAgent-subagents, VoltAgent, travisvn, BehiSecc, alirezarezvani, heilcheng, daymade, mxyhi, SkillsMP API), deduplicates them, and writes `cache/catalogue.json`
- `cache/catalogue.json` — Local skill catalogue (generated, not committed)
- `cache/last_update.txt` — Unix timestamp of last catalogue update

## How It Works

1. On invocation, checks catalogue freshness (>30 days = stale)
2. Searches `cache/catalogue.json` first (local, fast)
3. Falls back to SkillsMP live API if <2 local results (requires `SKILLSMP_API_KEY`)
4. Presents max 5 options ranked by source trust: Anthropic (105K) > ComposioHQ (49K) > vercel-labs (24K) > VoltAgent-subagents (15.5K) > VoltAgent (13K) > travisvn (10K) > BehiSecc/alirezarezvani (8K) > heilcheng (3.5K) > daymade/mxyhi > SkillsMP
5. Installs via `git clone` to `~/.claude/skills/` after user confirmation

## Commands

| Command | Description |
|---------|-------------|
| `/find-skill <query>` | Search for skills |
| `/install-skill <owner/repo>` | Install skill from GitHub |
| `/install-skill <url>` | Install skill by URL |
| `/install-skill <name>` | Install skill by catalogue name |

```bash
# Run catalogue update manually
~/.claude/skills/find-skill/update-skills-catalogue.sh

# Check last update date
cat ~/.claude/skills/find-skill/cache/last_update.txt | xargs -I{} date -r {}
```

## Notes

- The update script sources `~/.claude/skills/find-skill/.env` to load env vars (notably `SKILLSMP_API_KEY`)
- Cron schedule (when enabled): monthly — `0 0 1 * *`
- All text in `SKILL.md` is in Russian; maintain this convention
