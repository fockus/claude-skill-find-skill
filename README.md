# claude-skill-find-skill

Multi-agent skill discovery and installation — search **4800+ skills** from **14 sources** and install into **Claude Code, Codex, OpenCode, or Cursor** from a single shared catalogue with automatic format conversion.

## Install

### Homebrew (macOS / Linux)

```bash
brew tap fockus/tap
brew install find-skill
find-skill
```

### pipx

```bash
pipx install find-skill
find-skill
```

### One-liner (curl)

```bash
curl -sSL https://raw.githubusercontent.com/fockus/claude-skill-find-skill/main/quick-install.sh | bash
```

Auto-detects installed agents and sets up `/find-skill` + `/install-skill` in each. Pass target explicitly:

```bash
curl -sSL .../quick-install.sh | bash -s -- --target claude
curl -sSL .../quick-install.sh | bash -s -- --target opencode,cursor
curl -sSL .../quick-install.sh | bash -s -- --target all
```

### Manual install

```bash
git clone https://github.com/fockus/claude-skill-find-skill.git ~/.claude/skills/claude-skill-find-skill
cd ~/.claude/skills/claude-skill-find-skill
chmod +x install.sh uninstall.sh update-skills-catalogue.sh scripts/install-skill.sh
./install.sh
```

Installer options:
```bash
./install.sh                       # auto-detect installed agents
./install.sh --target claude       # Claude Code only
./install.sh --target codex,cursor # Codex + Cursor
./install.sh --target all          # all 4
```

## Supported agents

| Agent | Install path | Format |
|---|---|---|
| **Claude Code** | `~/.claude/skills/find-skill/SKILL.md` | Native skill folder |
| **Codex** | `~/.codex/skills/find-skill/SKILL.md` | Same format as Claude Code |
| **OpenCode** | `~/.config/opencode/command/find-skill.md` | Slash-command (converted) |
| **Cursor** | `~/.cursor/commands/find-skill.md` | User-level command (converted) |

All four versions read the **same shared catalogue** (`~/.claude/skills/find-skill/cache/catalogue.json`) — update once, every agent benefits.

## Usage

Same commands in every agent:

```
/find-skill docker                     # search for "docker" (filters to current agent)
/find-skill docker --agent any         # search entire catalogue (all 4800+ skills)
/find-skill react --agent cursor       # only Cursor-compatible skills
/find-skill deploy --all               # show all matches, not just top 5
/find-skill python --limit 10 --page 2 # paginated

/install-skill fockus/skill-name                  # install into current agent
/install-skill owner/repo --target all            # install into all 4 agents
/install-skill mono-repo --name sub-skill         # pick sub-skill from mono-repo
/install-skill https://github.com/user/skill-repo # full URL
/install-skill memory-bank                         # by name (looked up in catalogue)
```

### `/find-skill` flags

| Flag | Purpose | Default |
|------|---------|---------|
| `<query>` | Search term | — |
| `--agent <name>` | `claude`, `codex`, `opencode`, `cursor`, or `any` | current agent |
| `--limit N` | Max results per page | 5 |
| `--page N` | Pagination | 1 |
| `--all` | Show all matches | false |
| `--top N` | Top-N by stars across the whole catalogue | — |
| `--stats` | Catalogue stats by source and agent | — |

### `/install-skill` flags

| Flag | Purpose | Default |
|------|---------|---------|
| `<source>` | `owner/repo`, full URL, or catalogue name | — |
| `--target <list>` | Comma-separated targets, or `all` | current agent |
| `--name NAME` | Override skill name (for mono-repos, pick sub-skill) | derived from frontmatter |
| `--force` | Overwrite existing install | false |
| `--dry-run` | Print actions without writing | false |

## How it works

1. **Local-first search** — queries `cache/catalogue.json` (4835 skills, 2.5MB) offline
2. **Agent filtering** — each skill entry carries an `agents: [...]` array; results default to the current agent
3. **Ranked by trust** — source priority × GitHub stars (Anthropic 105K → SkillsMP marketplace at the bottom)
4. **Live API fallback** — if fewer than 2 local results, queries SkillsMP API (requires key)
5. **Install with conversion** — clones repo, detects SKILL.md (up to 4 levels deep for mono-repos), converts frontmatter per target agent

### Sources (14, total: 4835 skills)

| Source | Stars | Skills | Type |
|---|---:|---:|---|
| Anthropic | 105K | 17 | Official |
| ComposioHQ | 49K | 31 | Top awesome-list |
| hesreallyhim | 39.9K | 16 | Top awesome-list |
| skills.sh | — | **3999** | Official catalog (Vercel, multi-agent) |
| vercel-labs | 24K | 6 | Community |
| VoltAgent-subagents | 15.5K | 100 | Community |
| VoltAgent | 13K | 100 | Community |
| travisvn | 10K | 56 | Community |
| BehiSecc | 8K | 100 | Community |
| alirezarezvani | 8K | 3 | Community |
| heilcheng | 3.5K | 100 | Community |
| daymade | — | 100 | Community |
| mxyhi | — | 38 | Community |
| SkillsMP API | — | 352 | Marketplace |

### Agent distribution

| Agent | Compatible skills | Why |
|---|---:|---|
| `claude` | 4835 (100%) | SKILL.md is the native format |
| `codex` | 4835 (100%) | Uses same SKILL.md format as Claude |
| `opencode` | 3913 (81%) | skills.sh catalog (multi-agent) |
| `cursor` | 3913 (81%) | skills.sh catalog (multi-agent) |

## Catalogue updates

Catalogue does not auto-update. Run manually:

```bash
~/.claude/skills/find-skill/update-skills-catalogue.sh
```

Or schedule monthly:

```bash
(crontab -l 2>/dev/null; echo "0 0 1 * * $HOME/.claude/skills/find-skill/update-skills-catalogue.sh") | crontab -
```

Check last update:
```bash
date -r "$(cat ~/.claude/skills/find-skill/cache/last_update.txt)"
```

## API keys (optional)

The skill works offline with local catalogue. For expanded results, add marketplace keys:

| Service | Purpose | How to get |
|---|---|---|
| SkillsMP | Live marketplace search + +352 skills in catalogue | Register at skillsmp.com |

Keys live in `~/.claude/skills/find-skill/.env` (chmod 600, shared across all 4 agents).

## What gets installed

### Shared (single source of truth for all agents)

| File | Purpose |
|---|---|
| `~/.claude/skills/find-skill/cache/catalogue.json` | 4835 skills |
| `~/.claude/skills/find-skill/update-skills-catalogue.sh` | Refresh script |
| `~/.claude/skills/find-skill/scripts/install-skill.sh` | Universal installer with format conversion |
| `~/.claude/skills/find-skill/.env` | API keys |

### Per-agent (native commands/skills)

| Target | File |
|---|---|
| Claude Code | `~/.claude/skills/find-skill/SKILL.md` + `~/.claude/commands/find-skill.md` + `install-skill.md` |
| Codex | `~/.codex/skills/find-skill/SKILL.md` |
| OpenCode | `~/.config/opencode/command/find-skill.md` + `install-skill.md` (also `commands/` for legacy compat) |
| Cursor | `~/.cursor/commands/find-skill.md` + `install-skill.md` |

## Uninstall

```bash
~/.claude/skills/claude-skill-find-skill/uninstall.sh
```

Options:
```bash
./uninstall.sh                          # remove from all 4 agents + shared cache
./uninstall.sh --target opencode        # remove from OpenCode only
./uninstall.sh --keep-cache             # preserve 4835-skill catalogue + SkillsMP key
```

## Format conversion details

When `/install-skill <x> --target all` is run, the shared installer script converts Claude-style `SKILL.md` into each target's native format:

| Source | Claude Code SKILL.md frontmatter | Target frontmatter |
|---|---|---|
| → Codex | `name`, `description` | Same (1:1 copy) |
| → OpenCode | `name`, `description` | `description`, `argument-hint`, `tools: {read, write, bash, edit}` |
| → Cursor | `name`, `description` | `description`, `allowed-tools: [Bash, Read, Write, Edit]` |

Body of the skill is preserved verbatim — only the frontmatter header is rewritten.

## License

MIT
