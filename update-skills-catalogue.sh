#!/bin/bash
# update-skills-catalogue.sh
# Monthly catalogue update for Claude Code Skills
# Sources: Anthropic + ComposioHQ + vercel-labs + VoltAgent(subagents) + VoltAgent(skills) + travisvn + BehiSecc + alirezarezvani + heilcheng + daymade + mxyhi + hesreallyhim + skills.sh + SkillsMP API

CACHE_DIR="$HOME/.claude/skills/find-skill/cache"
CATALOGUE="$CACHE_DIR/catalogue.json"
LOG="$CACHE_DIR/update.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$CACHE_DIR"
echo "[$TIMESTAMP] Starting catalogue update..." | tee -a "$LOG"

# Load API key
source "$HOME/.claude/skills/find-skill/.env" 2>/dev/null
if [ -z "${SKILLSMP_API_KEY:-}" ]; then
    echo "⚠️  SKILLSMP_API_KEY not set. Add it to $HOME/.claude/skills/find-skill/.env" | tee -a "${LOG:-/dev/null}"
    echo "   Run: echo 'export SKILLSMP_API_KEY=\"your_key\"' >> $HOME/.claude/skills/find-skill/.env" | tee -a "${LOG:-/dev/null}"
fi

# Helper: parse awesome-list README pattern
# 4th arg AGENTS: comma-separated compatible agents (default: claude,codex — SKILL.md format)
parse_awesome_list() {
  SOURCE_NAME="$1" REPO="$2" STARS="$3" AGENTS="${4:-claude,codex}" python3 -c "
import sys, re, json, os
content = sys.stdin.read()
source_name = os.environ['SOURCE_NAME']
repo = os.environ['REPO']
stars = os.environ.get('STARS', '')
agents = [a.strip() for a in os.environ.get('AGENTS', 'claude,codex').split(',') if a.strip()]
skills = []
# Match: - **name** - description OR - [name](url) - description
pattern = r'[-*]\s+(?:\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)]+)\))\s*[-—:]\s*([^\n]+)'
matches = re.findall(pattern, content)
for m in matches:
    name = (m[0] or m[1]).strip()
    url = m[2].strip() if m[2] else None
    desc = m[3].strip()
    if len(name) > 2 and len(desc) > 10:
        skills.append({
            'name': name,
            'description': desc,
            'source': source_name,
            'repo': repo,
            'repo_url': url or f'https://github.com/{repo}',
            'install_url': url,
            'confidence': 'community-verified',
            'stars': stars or None,
            'tags': [],
            'agents': agents,
            'category': 'community'
        })
print(json.dumps(skills[:100]))
" 2>/dev/null || echo "[]"
}

# Helper: parse GitHub API directory listing
# 4th arg AGENTS: comma-separated compatible agents (default: claude,codex)
parse_github_dirs() {
  SOURCE_NAME="$1" REPO="$2" CONFIDENCE="$3" AGENTS="${4:-claude,codex}" python3 -c "
import json, sys, os
data = json.load(sys.stdin)
source_name = os.environ['SOURCE_NAME']
repo = os.environ['REPO']
confidence = os.environ['CONFIDENCE']
agents = [a.strip() for a in os.environ.get('AGENTS', 'claude,codex').split(',') if a.strip()]
skills = []
if isinstance(data, list):
    for item in data:
        if item.get('type') == 'dir':
            skills.append({
                'name': item['name'],
                'description': f'{source_name} skill — {item[\"name\"]}',
                'source': source_name,
                'repo': repo,
                'repo_url': f'https://github.com/{repo}',
                'install_url': f'https://github.com/{repo}',
                'confidence': confidence,
                'stars': None,
                'tags': [source_name.lower()],
                'agents': agents,
                'category': 'docs'
            })
print(json.dumps(skills))
" 2>/dev/null || echo "[]"
}

count_json() {
  echo "$1" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo "0"
}

# ─────────────────────────────────────────
# SOURCE 1: Anthropic official
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching Anthropic official..." | tee -a "$LOG"
ANTHROPIC_SKILLS=$(curl -sf "https://api.github.com/repos/anthropics/skills/contents/skills" | parse_github_dirs "Anthropic" "anthropics/skills" "official")
echo "  → $(count_json "$ANTHROPIC_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 2: travisvn/awesome-claude-skills
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching travisvn..." | tee -a "$LOG"
TRAVISVN_SKILLS=$(curl -sf "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" | parse_awesome_list "travisvn" "travisvn/awesome-claude-skills" "9600")
echo "  → $(count_json "$TRAVISVN_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 3: BehiSecc/awesome-claude-skills
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching BehiSecc..." | tee -a "$LOG"
BEHISECC_SKILLS=$(curl -sf "https://raw.githubusercontent.com/BehiSecc/awesome-claude-skills/main/README.md" | parse_awesome_list "BehiSecc" "BehiSecc/awesome-claude-skills" "5600")
echo "  → $(count_json "$BEHISECC_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 4: VoltAgent/awesome-agent-skills
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching VoltAgent..." | tee -a "$LOG"
VOLTAGENT_SKILLS=$(curl -sf "https://raw.githubusercontent.com/VoltAgent/awesome-agent-skills/main/README.md" | parse_awesome_list "VoltAgent" "VoltAgent/awesome-agent-skills" "")
echo "  → $(count_json "$VOLTAGENT_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 5: alirezarezvani/claude-skills (192+ skills)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching alirezarezvani..." | tee -a "$LOG"
ALIREZAREZVANI_SKILLS=$(curl -sf "https://raw.githubusercontent.com/alirezarezvani/claude-skills/main/README.md" | parse_awesome_list "alirezarezvani" "alirezarezvani/claude-skills" "")
echo "  → $(count_json "$ALIREZAREZVANI_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 6: mxyhi/ok-skills
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching mxyhi/ok-skills..." | tee -a "$LOG"
MXYHI_SKILLS=$(curl -sf "https://raw.githubusercontent.com/mxyhi/ok-skills/main/README.md" | parse_awesome_list "mxyhi" "mxyhi/ok-skills" "188")
echo "  → $(count_json "$MXYHI_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 7: daymade/claude-code-skills (43 production-ready)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching daymade..." | tee -a "$LOG"
DAYMADE_SKILLS=$(curl -sf "https://raw.githubusercontent.com/daymade/claude-code-skills/main/README.md" | parse_awesome_list "daymade" "daymade/claude-code-skills" "")
echo "  → $(count_json "$DAYMADE_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 8: ComposioHQ/awesome-claude-skills
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching ComposioHQ..." | tee -a "$LOG"
COMPOSIO_SKILLS=$(curl -sf "https://api.github.com/repos/ComposioHQ/awesome-claude-skills/contents" | parse_github_dirs "ComposioHQ" "ComposioHQ/awesome-claude-skills" "community-verified")
echo "  → $(count_json "$COMPOSIO_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 9: vercel-labs/agent-skills (24K stars)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching vercel-labs..." | tee -a "$LOG"
VERCEL_SKILLS=$(curl -sf "https://raw.githubusercontent.com/vercel-labs/agent-skills/main/README.md" | python3 -c "
import sys, re, json
content = sys.stdin.read()
skills = []
# Format: ### skill-name\n\nDescription paragraph
blocks = re.split(r'^### ', content, flags=re.MULTILINE)[1:]
for block in blocks:
    lines = block.strip().split('\n')
    name = lines[0].strip()
    desc_lines = []
    for line in lines[1:]:
        line = line.strip()
        if line.startswith('**') or line.startswith('-') or not line:
            if desc_lines:
                break
            continue
        desc_lines.append(line)
    desc = ' '.join(desc_lines)[:200] if desc_lines else f'Vercel agent skill — {name}'
    if len(name) > 2:
        skills.append({
            'name': name,
            'description': desc,
            'source': 'vercel-labs',
            'repo': 'vercel-labs/agent-skills',
            'repo_url': 'https://github.com/vercel-labs/agent-skills',
            'install_url': 'https://github.com/vercel-labs/agent-skills',
            'confidence': 'community-verified',
            'stars': '24059',
            'tags': ['vercel', 'react', 'nextjs'],
            'agents': ['claude', 'codex'],
            'category': 'community'
        })
print(json.dumps(skills))
" 2>/dev/null || echo "[]")
echo "  → $(count_json "$VERCEL_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 10: VoltAgent/awesome-claude-code-subagents (15.5K stars)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching VoltAgent subagents..." | tee -a "$LOG"
VOLTAGENT_SUB_SKILLS=$(curl -sf "https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/README.md" | parse_awesome_list "VoltAgent-subagents" "VoltAgent/awesome-claude-code-subagents" "15557")
echo "  → $(count_json "$VOLTAGENT_SUB_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 11: heilcheng/awesome-agent-skills (3.5K stars)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching heilcheng..." | tee -a "$LOG"
HEILCHENG_SKILLS=$(curl -sf "https://raw.githubusercontent.com/heilcheng/awesome-agent-skills/main/README.md" | parse_awesome_list "heilcheng" "heilcheng/awesome-agent-skills" "3483")
echo "  → $(count_json "$HEILCHENG_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 12: hesreallyhim/awesome-claude-code (39.9K stars — top awesome-list)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching hesreallyhim/awesome-claude-code..." | tee -a "$LOG"
HESREALLYHIM_SKILLS=$(curl -sf "https://raw.githubusercontent.com/hesreallyhim/awesome-claude-code/main/README.md" | parse_awesome_list "hesreallyhim" "hesreallyhim/awesome-claude-code" "39900")
echo "  → $(count_json "$HESREALLYHIM_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 13: skills.sh (Vercel-curated catalog, ~4K skills via sitemap)
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Fetching skills.sh sitemap..." | tee -a "$LOG"
SKILLS_SH_SKILLS=$(curl -sf "https://skills.sh/sitemap.xml" | python3 -c "
import sys, re, json
content = sys.stdin.read()
skills = []
seen = set()
# Extract URLs of format https://skills.sh/<owner>/<repo>/<skill-name>
pattern = r'<loc>https://skills\.sh/([^/<]+)/([^/<]+)/([^<]+)</loc>'
# Meta pages to skip (they appear as first path segment)
meta_paths = {'picks', 'trending', 'hot', 'official', 'audits', 'docs', 'search', 'site', 'package', 'api', 's', 'internal', '.well-known', 'debug-security'}
for m in re.findall(pattern, content):
    owner, repo, skill_name = m
    if owner in meta_paths:
        continue
    key = skill_name.lower().strip()
    if not key or key in seen:
        continue
    seen.add(key)
    skills.append({
        'name': skill_name,
        'description': f'{skill_name} — skill from {owner}/{repo} (via skills.sh)',
        'source': 'skills.sh',
        'repo': f'{owner}/{repo}',
        'repo_url': f'https://github.com/{owner}/{repo}',
        'install_url': f'https://skills.sh/{owner}/{repo}/{skill_name}',
        'confidence': 'official-catalog',
        'stars': None,
        'tags': ['skills.sh', 'vercel-curated'],
        'agents': ['claude', 'codex', 'opencode', 'cursor'],
        'category': 'catalog'
    })
print(json.dumps(skills))
" 2>/dev/null || echo "[]")
echo "  → $(count_json "$SKILLS_SH_SKILLS") skills found" | tee -a "$LOG"

# ─────────────────────────────────────────
# SOURCE 14: SkillsMP API
# ─────────────────────────────────────────
SKILLSMP_SKILLS="[]"
if [ -n "$SKILLSMP_API_KEY" ]; then
  echo "[$TIMESTAMP] Fetching SkillsMP API..." | tee -a "$LOG"
  > "$CACHE_DIR/_skillsmp_raw.jsonl"
  for query in "claude" "react" "python" "docker" "aws" "database" "design" "testing" "deploy" "frontend" "backend" "devops" "security" "mobile"; do
    curl -sf "https://skillsmp.com/api/v1/skills/search?q=$query&limit=100" \
      -H "Authorization: Bearer $SKILLSMP_API_KEY" >> "$CACHE_DIR/_skillsmp_raw.jsonl"
    echo "" >> "$CACHE_DIR/_skillsmp_raw.jsonl"
    sleep 0.5
  done
  SKILLSMP_SKILLS=$(CACHE_DIR_ENV="$CACHE_DIR" python3 -c "
import json, os

raw_path = os.path.join(os.environ['CACHE_DIR_ENV'], '_skillsmp_raw.jsonl')
all_skills = []
seen = set()

with open(raw_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            resp = json.loads(line)
            skills = resp.get('data', {}).get('skills', [])
            for s in skills:
                name = s.get('name', '')
                if name.lower() not in seen and name:
                    seen.add(name.lower())
                    all_skills.append({
                        'name': name,
                        'description': s.get('description', '')[:200],
                        'source': 'SkillsMP',
                        'repo': s.get('author', '') + '/' + name,
                        'repo_url': s.get('githubUrl', ''),
                        'install_url': s.get('githubUrl', ''),
                        'confidence': 'community',
                        'stars': str(s.get('stars', 0)),
                        'tags': [s.get('author', '')],
                        'agents': ['claude', 'codex'],
                        'category': 'community'
                    })
        except:
            pass

os.remove(raw_path)
print(json.dumps(all_skills))
" 2>/dev/null || echo "[]")
  echo "  → $(count_json "$SKILLSMP_SKILLS") skills found" | tee -a "$LOG"
else
  echo "[$TIMESTAMP] ⚠️ SKILLSMP_API_KEY not set — source skipped" | tee -a "$LOG"
fi

# ─────────────────────────────────────────
# MERGE and SAVE catalogue
# ─────────────────────────────────────────
echo "[$TIMESTAMP] Merging sources..." | tee -a "$LOG"

ALL_SOURCES=("anthropic" "travisvn" "behisecc" "voltagent" "alirezarezvani" "mxyhi" "daymade" "composio" "vercel" "voltagent_sub" "heilcheng" "hesreallyhim" "skills_sh" "skillsmp")
ALL_DATA=("$ANTHROPIC_SKILLS" "$TRAVISVN_SKILLS" "$BEHISECC_SKILLS" "$VOLTAGENT_SKILLS" "$ALIREZAREZVANI_SKILLS" "$MXYHI_SKILLS" "$DAYMADE_SKILLS" "$COMPOSIO_SKILLS" "$VERCEL_SKILLS" "$VOLTAGENT_SUB_SKILLS" "$HEILCHENG_SKILLS" "$HESREALLYHIM_SKILLS" "$SKILLS_SH_SKILLS" "$SKILLSMP_SKILLS")

for i in "${!ALL_SOURCES[@]}"; do
  echo "${ALL_DATA[$i]}" > "$CACHE_DIR/_${ALL_SOURCES[$i]}.json"
done

CACHE_DIR_ENV="$CACHE_DIR" CATALOGUE_ENV="$CATALOGUE" ALL_SOURCES_STR="${ALL_SOURCES[*]}" python3 -c "
import json, os
from datetime import datetime, timezone

cache_dir = os.environ['CACHE_DIR_ENV']
catalogue_path = os.environ['CATALOGUE_ENV']
source_names = os.environ.get('ALL_SOURCES_STR', '').split()

sources = {}
for name in source_names:
    path = os.path.join(cache_dir, f'_{name}.json')
    try:
        with open(path) as f:
            sources[name] = json.load(f)
    except:
        sources[name] = []
    try:
        os.remove(path)
    except:
        pass

all_skills = []
seen = set()
for source, skills in sources.items():
    for s in skills:
        key = s['name'].lower().strip()
        if key not in seen and len(key) > 1:
            seen.add(key)
            all_skills.append(s)

catalogue = {
    'updated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'total': len(all_skills),
    'sources': {name: len(skills) for name, skills in sources.items()},
    'skills': all_skills
}

with open(catalogue_path, 'w') as f:
    json.dump(catalogue, f, indent=2, ensure_ascii=False)

print(f'✅ Catalogue saved: {len(all_skills)} unique skills')
"

# Save timestamp
date +%s > "$CACHE_DIR/last_update.txt"

TOTAL=$(cat "$CATALOGUE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['total'])" 2>/dev/null)
echo "[$TIMESTAMP] ✅ Update complete — $TOTAL skills in catalogue" | tee -a "$LOG"
echo ""
echo "📊 Summary:"
cat "$CATALOGUE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'  Total unique    : {d[\"total\"]} skills')
for source, count in d['sources'].items():
    print(f'  {source:<15} : {count} skills')
print(f'  Updated at      : {d[\"updated_at\"]}')
"
