# claude-skill-find-skill

Discover, search, and install Claude Code skills from 12 community and official sources. Maintains a local JSON catalogue with optional SkillsMP marketplace API integration.

## Install

```bash
git clone https://github.com/fockus/claude-skill-find-skill.git ~/.claude/skills/claude-skill-find-skill
cd ~/.claude/skills/claude-skill-find-skill && chmod +x install.sh uninstall.sh update-skills-catalogue.sh && ./install.sh
```

The installer will:
1. Copy skill files to `~/.claude/skills/find-skill/`
2. Ask for optional SkillsMP API key
3. Offer to fetch the initial skill catalogue

## Usage

In Claude Code:

```
/find-skill docker         # Find Docker-related skills
/find-skill testing        # Find testing skills
/find-skill react          # Find React skills
/find-skill deploy --all   # Show all deploy-related skills
```

### Parameters

| Param | Description |
|-------|-------------|
| `<query>` | Search term (required) |
| `--all` | Show all matches, not just top 5 |
| `--limit N` | Max results to show (default: 5) |
| `--page N` | Pagination for large result sets |

## How It Works

1. Searches local `cache/catalogue.json` first (fast, offline)
2. If <2 local results — queries SkillsMP live API (requires API key)
3. Results ranked by source trust level (GitHub stars)
4. Install via `git clone` after user confirmation

## Sources (12, ranked by GitHub stars)

| Source | Stars | Type |
|--------|-------|------|
| Anthropic | 105K | Official |
| ComposioHQ | 49K | Community |
| vercel-labs | 24K | Community |
| VoltAgent-subagents | 15.5K | Community |
| VoltAgent | 13K | Community |
| travisvn | 10K | Community |
| BehiSecc/alirezarezvani | 8K | Community |
| heilcheng | 3.5K | Community |
| daymade | — | Community |
| mxyhi | — | Community |
| SkillsMP API | — | Marketplace |

## Catalogue Updates

The catalogue is not auto-updated. Run manually when needed:

```bash
~/.claude/skills/find-skill/update-skills-catalogue.sh
```

Optional: schedule via cron for monthly updates:

```bash
(crontab -l 2>/dev/null; echo "0 0 1 * * $HOME/.claude/skills/find-skill/update-skills-catalogue.sh") | crontab -
```

Check last update:

```bash
cat ~/.claude/skills/find-skill/cache/last_update.txt
```

## API Keys

Optional. The skill works without API keys using the local catalogue.

| Service | Purpose | How to get |
|---------|---------|-----------|
| SkillsMP | Live marketplace search | Register at skillsmp.com |

Keys are stored in `~/.claude/skills/find-skill/.env` (chmod 600, not committed to git).

## What Gets Installed

| File | Location |
|------|----------|
| SKILL.md | `~/.claude/skills/find-skill/` |
| CLAUDE.md | `~/.claude/skills/find-skill/` |
| update-skills-catalogue.sh | `~/.claude/skills/find-skill/` |
| .env (API keys) | `~/.claude/skills/find-skill/` |
| cache/catalogue.json | `~/.claude/skills/find-skill/cache/` |

## Uninstall

```bash
cd ~/.claude/skills/claude-skill-find-skill && ./uninstall.sh
```

Removes `~/.claude/skills/find-skill/` and cleans up cron entries.

## License

MIT
