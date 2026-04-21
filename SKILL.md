---
name: find-skill
description: Finds and installs Claude Code Skills for your project. 14 sources, ranked by GitHub stars. Examples: "find a skill for Docker", "search for testing skills", "show all React skills". Supports parameters: limit (how many to show), page (pagination), --all (show all results).
---

# Find Skill — skill discovery and installation

You are an expert skill finder with a local catalogue (14 sources, ranked by GitHub stars).

---

## Input parameters

The skill accepts free-form arguments. Parse them as follows:

| Format | Example | Meaning |
|--------|---------|---------|
| `<query>` | `docker` | Keyword search, show top 3 |
| `<query> --limit N` | `react --limit 10` | Show N results |
| `<query> --all` | `design --all` | Show ALL matching results |
| `<query> --page N` | `python --limit 5 --page 2` | Page N (with `limit` per page) |
| `<query> --agent <name>` | `docker --agent cursor` | Filter by agent: `claude`, `codex`, `opencode`, `cursor`, `any` |
| `--top N` | `--top 20` | Show top-N skills by stars across the entire catalogue |
| `--stats` | `--stats` | Catalogue stats by source and agent |
| `--category <cat>` | `--category design` | All skills in a category |

**Defaults:** limit=5, page=1, **agent=claude** (current agent — Claude Code).

**Note on `--agent`:** by default only skills compatible with the current agent (Claude Code) are shown. Use `--agent any` to remove the filter and see the full catalogue, `--agent cursor` to find skills for Cursor only, etc.

---

## Stage 0 — Check catalogue freshness

```bash
CACHE_FILE="$HOME/.claude/skills/find-skill/cache/catalogue.json"
LAST_UPDATE="$HOME/.claude/skills/find-skill/cache/last_update.txt"

if [ ! -f "$LAST_UPDATE" ]; then
  echo "Catalogue not initialized — update required"
  NEEDS_UPDATE=true
else
  LAST=$(cat "$LAST_UPDATE")
  NOW=$(date +%s)
  DIFF=$(( (NOW - LAST) / 86400 ))
  if [ "$DIFF" -gt 30 ]; then
    echo "Catalogue is stale ($DIFF days old) — update required"
    NEEDS_UPDATE=true
  else
    echo "Catalogue is fresh (updated $DIFF days ago)"
    NEEDS_UPDATE=false
  fi
fi
```

If `NEEDS_UPDATE=true` — run `~/.claude/skills/find-skill/update-skills-catalogue.sh`.

---

## Stage 1 — Understand the query

If the query is unclear — ask 1-2 questions:
- What stack / language / framework?
- What specific task is this for?

If the query is clear — proceed directly to stage 2.

---

## Stage 2 — Search the local catalogue

```bash
cat ~/.claude/skills/find-skill/cache/catalogue.json | \
  python3 -c "
import json, sys, re

data = json.load(sys.stdin)
query = 'QUERY'.lower()
limit = LIMIT        # replace with number from parameter
page = PAGE          # replace with number from parameter
show_all = SHOW_ALL  # True/False
agent_filter = 'AGENT_FILTER'  # 'claude', 'codex', 'opencode', 'cursor', 'any'

# Source priority — scores proportional to GitHub stars (April 2026)
SOURCE_PRIORITY = {
    'Anthropic': 60,              # 105K stars — official Anthropic skills
    'skills.sh': 30,              # Vercel-curated catalogue, ~4K skills
    'hesreallyhim': 28,           # 39.9K stars — top awesome-list
    'ComposioHQ': 25,             # 49K stars — curated list
    'vercel-labs': 12,            # 24K stars — Vercel agent skills
    'VoltAgent-subagents': 8,     # 15.5K stars — Claude Code subagents
    'VoltAgent': 7,               # 13K stars — awesome agent skills
    'travisvn': 5,                # 10K stars — curated list
    'BehiSecc': 4,                # 8K stars — curated list
    'alirezarezvani': 4,          # 8K stars — large collection
    'heilcheng': 3,               # 3.5K stars — awesome agent skills
    'daymade': 3,                 # 744 stars — production-ready collection
    'mxyhi': 3,                   # 188 stars — ok-skills
    'SkillsMP': 3,                # Marketplace (many, but less vetted)
}

# Search: name, description, tags + agent filter
results = []
for s in data['skills']:
    # Agent filter (if agent_filter != 'any')
    if agent_filter and agent_filter != 'any':
        skill_agents = s.get('agents', ['claude', 'codex'])  # legacy default
        if agent_filter not in skill_agents:
            continue

    score = 0
    name_l = s['name'].lower()
    desc_l = s.get('description', '').lower()
    tags_l = [t.lower() for t in s.get('tags', [])]

    # Query relevance
    if query == name_l:
        score = 100
    elif query in name_l:
        score = 50
    elif query in desc_l:
        score = 20
    elif any(query in t for t in tags_l):
        score = 10

    if score > 0:
        # Bonus for source (trust priority)
        source = s.get('source', '')
        source_bonus = SOURCE_PRIORITY.get(source, 0)

        # Bonus for stars (max +20)
        try:
            stars = int(str(s.get('stars', 0) or 0).replace(',','').replace('+',''))
        except:
            stars = 0
        stars_bonus = min(stars / 1000, 20)

        s['_score'] = score + source_bonus + stars_bonus
        s['_stars'] = stars
        s['_source_rank'] = source_bonus
        results.append(s)

# Sort: score desc (includes source + stars), then stars desc
results.sort(key=lambda x: (-x['_score'], -x['_stars']))

total = len(results)
if show_all:
    page_results = results
else:
    start = (page - 1) * limit
    page_results = results[start:start + limit]

total_pages = (total + limit - 1) // limit if not show_all else 1

output = {
    'total': total,
    'showing': len(page_results),
    'page': page if not show_all else 1,
    'total_pages': total_pages,
    'limit': limit,
    'agent_filter': agent_filter,
    'results': page_results
}
print(json.dumps(output, indent=2, ensure_ascii=False))
"
```

**How to use `agent_filter`:**
- Default for this file: `agent_filter = 'claude'` (we are in Claude Code)
- If user specified `--agent any` — show full catalogue (agent_filter = 'any')
- If specified `--agent cursor|codex|opencode` — substitute that value
- In `--stats` display distribution by agent

---

## Stage 3 — Live search (if catalogue returns < 2 results)

### SkillsMP API:
```bash
source "$HOME/.claude/skills/find-skill/.env" 2>/dev/null

# Keyword search
curl -s "https://skillsmp.com/api/v1/skills/search?q=QUERY&limit=LIMIT" \
  -H "Authorization: Bearer $SKILLSMP_API_KEY"

# AI semantic search
curl -s "https://skillsmp.com/api/v1/skills/ai-search?q=QUERY+CONTEXT" \
  -H "Authorization: Bearer $SKILLSMP_API_KEY"
```

---

## Stage 4 — Show results

**Never install without confirmation.**

Output format depends on the number of results:

### Trust levels (by source, stars as of April 2026):
```
Anthropic (105K)                              → Official (green)
skills.sh (Vercel-curated, ~4K entries)       → Official catalogue (green)
hesreallyhim (39.9K) / ComposioHQ (49K)       → Top awesome-list (green)
vercel-labs (24K)                             → Curated (yellow)
VoltAgent-subagents (15.5K) / VoltAgent (13K) → Curated (yellow)
travisvn (10K) / BehiSecc (8K)                → Curated (yellow)
alirezarezvani (8K) / heilcheng (3.5K)        → Community-vetted (orange)
daymade (744) / mxyhi (188)                   → Community (orange)
SkillsMP                                      → Marketplace (grey, verify manually)
```

### Compact (up to 5 results):
```
Found N skills for "QUERY":

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. [name] (RECOMMENDED)
   Source      : Anthropic        | Trust: Official
   Description : [1-2 sentences]
   Stars       : [N]
   Repo        : [URL]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. [name]
   Source      : SkillsMP         | Trust: Marketplace — verify repo
   ...

Install? (1, 2, all, or no)
```

### Table (6+ results):
```
Found N skills for "QUERY" (page PAGE/TOTAL_PAGES):

| #  | Name              | Source     | Trust   | Stars  | Description (brief)    |
|----|-------------------|------------|---------|--------|------------------------|
| 1  | skill-name        | Anthropic  | Offic.  | 9600   | Brief description...   |
| 2  | another-skill     | travisvn   | Curat.  | 5600   | Brief description...   |
| 3  | some-skill        | SkillsMP   | Market. | 120    | Brief description...   |

Page PAGE of TOTAL_PAGES. Next: /find-skill QUERY --page NEXT
Install? (number, range 1-3, all, or no)
```

Results are automatically sorted: official and curated first, then community, marketplace last. Within the same source — sorted by stars.

---

## Stage 5 — Install after confirmation

```bash
mkdir -p ~/.claude/skills
git clone [REPO_URL] ~/.claude/skills/[SKILL_NAME]
echo "Skill [SKILL_NAME] installed"

# Verify
ls ~/.claude/skills/[SKILL_NAME]/
head -10 ~/.claude/skills/[SKILL_NAME]/SKILL.md
```

---

## Stage 6 — Confirm and explain

After installation:
1. Where the skill was installed
2. How to activate it (`/skill-name` or automatically)
3. An example of how to use it in the current project

---

## Special commands

| Query | Action |
|-------|--------|
| `update catalogue` | Run `update-skills-catalogue.sh` |
| `when was catalogue updated?` | Show date from `last_update.txt` |
| `show full catalogue` | All skills by category |
| `--top 20` | Top-20 by stars |
| `--stats` | Stats by source |
| `react --all` | All skills matching query |
| `python --limit 10 --page 2` | Page 2 with 10 results per page |

---

## Rules

- **Never install without confirmation**
- **Cache first, then API** (saves 500 req/day)
- **Default 5 results**, but user can request more
- **Flag risks** if the source is unknown
- **Priority**: Anthropic (105K) > skills.sh (Vercel-catalog) > hesreallyhim (39.9K) > ComposioHQ (49K) > vercel-labs (24K) > VoltAgent-subagents (15.5K) > VoltAgent (13K) > travisvn (10K) > BehiSecc/alirezarezvani (8K) > heilcheng (3.5K) > daymade/mxyhi > SkillsMP
- **Table format** for 6+ results to keep output compact

---

## Deactivation / removal

### Temporarily disable
```bash
mv ~/.claude/skills/find-skill ~/.claude/skills/find-skill-disabled
```

### Re-enable
```bash
mv ~/.claude/skills/find-skill-disabled ~/.claude/skills/find-skill
```

### Stop auto-update (cron)
```bash
crontab -l | grep -v "update-skills-catalogue" | crontab -
```

### Remove completely
```bash
crontab -l | grep -v "update-skills-catalogue" | crontab -
rm -rf ~/.claude/skills/find-skill
```
