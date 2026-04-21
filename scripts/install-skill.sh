#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# install-skill.sh — Universal skill installer
# Installs a skill from GitHub into any of: Claude Code, Codex,
# OpenCode, Cursor. Auto-converts format per agent.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# Native install paths
CC_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"
OPENCODE_COMMANDS="$HOME/.config/opencode/command"
OPENCODE_COMMANDS_PLURAL="$HOME/.config/opencode/commands"
CURSOR_COMMANDS="$HOME/.cursor/commands"

usage() {
  cat <<EOF
Usage: $0 <skill-source> [OPTIONS]

Skill source can be:
  owner/repo                GitHub short reference
  https://github.com/...    Full URL
  <name>                    Name from catalogue (~/.claude/skills/find-skill/cache/catalogue.json)

Options:
  --target TARGET[,...]     Target agents: claude, codex, opencode, cursor, all
                            Default: auto-detect current agent (see \$CLAUDE_CODE_AGENT env)
  --name NAME               Override skill name (default: repo name)
  --force                   Overwrite existing install
  --dry-run                 Print actions without executing

Examples:
  $0 fockus/claude-skill-build
  $0 memory-bank --target all
  $0 https://github.com/user/skill-repo --target cursor
EOF
  exit 0
}

# ─────────────────────────────────────────
# Parse args
# ─────────────────────────────────────────
SKILL_SRC=""
TARGETS=()
NAME_OVERRIDE=""
FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target|-t) IFS=',' read -ra REQ <<< "$2"; TARGETS+=("${REQ[@]}"); shift 2 ;;
    --name|-n)   NAME_OVERRIDE="$2"; shift 2 ;;
    --force|-f)  FORCE=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --help|-h)   usage ;;
    -*)          echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
    *)           [ -z "$SKILL_SRC" ] && SKILL_SRC="$1" || { echo -e "${RED}Too many positional args${NC}" >&2; exit 1; }; shift ;;
  esac
done

[ -z "$SKILL_SRC" ] && usage

# ─────────────────────────────────────────
# Resolve targets: explicit or auto-detect
# ─────────────────────────────────────────
if [ ${#TARGETS[@]} -eq 0 ]; then
  # Prefer explicit env var, fallback to detecting from cwd/user
  if [ -n "${CLAUDE_CODE_AGENT:-}" ]; then
    TARGETS=("$CLAUDE_CODE_AGENT")
  else
    # Single-target default: Claude Code (this script is invoked from a skill,
    # and the skill knows its agent)
    TARGETS=("claude")
  fi
fi

if [[ " ${TARGETS[*]} " == *" all "* ]]; then
  TARGETS=("claude" "codex" "opencode" "cursor")
fi

# Validate
VALID=("claude" "codex" "opencode" "cursor")
for t in "${TARGETS[@]}"; do
  found=0
  for v in "${VALID[@]}"; do [ "$t" = "$v" ] && found=1; done
  [ $found -eq 0 ] && { echo -e "${RED}Invalid target: $t${NC}" >&2; exit 1; }
done

# ─────────────────────────────────────────
# Resolve skill source → git URL
# ─────────────────────────────────────────
CATALOGUE="$HOME/.claude/skills/find-skill/cache/catalogue.json"

resolve_url() {
  local src="$1"
  # Full URL
  if [[ "$src" =~ ^https?:// ]]; then
    echo "$src"; return
  fi
  # owner/repo
  if [[ "$src" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "https://github.com/$src"; return
  fi
  # Lookup in catalogue by name
  if [ -f "$CATALOGUE" ]; then
    local url
    url=$(SKILL_NAME="$src" python3 -c "
import json, os
with open(os.path.expanduser('~/.claude/skills/find-skill/cache/catalogue.json')) as f:
    d = json.load(f)
name = os.environ['SKILL_NAME'].lower()
for s in d['skills']:
    if s['name'].lower() == name:
        url = s.get('repo_url') or s.get('install_url') or ''
        if url:
            print(url)
            break
" 2>/dev/null)
    if [ -n "$url" ]; then
      echo "$url"; return
    fi
  fi
  echo -e "${RED}Cannot resolve skill source: $src${NC}" >&2
  echo -e "  Try: owner/repo, full URL, or catalogue skill name" >&2
  exit 1
}

REPO_URL=$(resolve_url "$SKILL_SRC")
echo -e "${BLUE}Resolved URL:${NC} $REPO_URL"

# ─────────────────────────────────────────
# Clone to temp
# ─────────────────────────────────────────
TMPDIR=$(mktemp -d -t install-skill-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

echo -e "${BLUE}Cloning...${NC}"
if [ $DRY_RUN -eq 1 ]; then
  echo "  [dry-run] git clone --depth 1 $REPO_URL $TMPDIR/src"
  mkdir -p "$TMPDIR/src"
  # Fake SKILL.md for dry-run test
  printf -- "---\nname: fake-skill\ndescription: Dry-run test\n---\n" > "$TMPDIR/src/SKILL.md"
else
  git clone --depth 1 "$REPO_URL" "$TMPDIR/src" 2>&1 | tail -3 || {
    echo -e "${RED}Clone failed${NC}" >&2; exit 1
  }
fi

# ─────────────────────────────────────────
# Locate SKILL.md (or main .md)
# ─────────────────────────────────────────
SKILL_MD=""
if [ -f "$TMPDIR/src/SKILL.md" ]; then
  SKILL_MD="$TMPDIR/src/SKILL.md"
  SKILL_ROOT="$TMPDIR/src"
else
  # Search up to 4 levels deep (handles mono-repos with skills/<name>/SKILL.md)
  MATCHES=$(find "$TMPDIR/src" -maxdepth 4 -name "SKILL.md" 2>/dev/null)
  COUNT=$(echo "$MATCHES" | grep -c . || true)
  if [ "$COUNT" -gt 1 ]; then
    echo -e "${YELLOW}Mono-repo detected — $COUNT skills inside:${NC}"
    echo "$MATCHES" | sed "s|$TMPDIR/src/|  |" | head -20
    # If --name was given, try to match
    if [ -n "$NAME_OVERRIDE" ]; then
      SKILL_MD=$(echo "$MATCHES" | grep "/$NAME_OVERRIDE/SKILL.md" | head -1)
      [ -n "$SKILL_MD" ] && echo -e "${GREEN}Matched --name $NAME_OVERRIDE → $SKILL_MD${NC}"
    fi
    if [ -z "$SKILL_MD" ]; then
      SKILL_MD=$(echo "$MATCHES" | head -1)
      echo -e "${YELLOW}Using first match. Use --name <subname> to pick a specific one.${NC}"
    fi
    SKILL_ROOT=$(dirname "$SKILL_MD")
  elif [ "$COUNT" -eq 1 ]; then
    SKILL_MD="$MATCHES"
    SKILL_ROOT=$(dirname "$SKILL_MD")
  else
    echo -e "${YELLOW}No SKILL.md found — using README.md as fallback${NC}"
    SKILL_MD=$(find "$TMPDIR/src" -maxdepth 2 -iname "README.md" 2>/dev/null | head -1)
    [ -z "$SKILL_MD" ] && { echo -e "${RED}No SKILL.md or README.md${NC}" >&2; exit 1; }
    SKILL_ROOT=$(dirname "$SKILL_MD")
  fi
fi

# Extract name + description from frontmatter — use null-separated k=v for safe parse
NAME=$(SKILL_MD_PATH="$SKILL_MD" python3 -c "
import os, re
with open(os.environ['SKILL_MD_PATH']) as f:
    content = f.read()
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if m:
    nm = re.search(r'^name:\s*(.+)\$', m.group(1), re.MULTILINE)
    print(nm.group(1).strip().strip('\"\\'') if nm else 'unknown')
else:
    print('unknown')
" 2>/dev/null)

DESC=$(SKILL_MD_PATH="$SKILL_MD" python3 -c "
import os, re
with open(os.environ['SKILL_MD_PATH']) as f:
    content = f.read()
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
if m:
    dm = re.search(r'^description:\s*(.+)\$', m.group(1), re.MULTILINE)
    print(dm.group(1).strip().strip('\"\\'') if dm else '')
" 2>/dev/null)

BODY_OFFSET=$(SKILL_MD_PATH="$SKILL_MD" python3 -c "
import os, re
with open(os.environ['SKILL_MD_PATH']) as f:
    content = f.read()
m = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
print(m.end() if m else 0)
" 2>/dev/null)

SKILL_NAME="${NAME_OVERRIDE:-$NAME}"
# Sanitize name
SKILL_NAME=$(echo "$SKILL_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9_-')
[ -z "$SKILL_NAME" ] && { echo -e "${RED}Could not determine skill name${NC}" >&2; exit 1; }

echo -e "${BLUE}Name:${NC}        $SKILL_NAME"
echo -e "${BLUE}Description:${NC} ${DESC:0:80}..."
echo ""

# ─────────────────────────────────────────
# Per-target install
# ─────────────────────────────────────────
install_claude() {
  local dest="$CC_SKILLS/$SKILL_NAME"
  if [ -e "$dest" ] && [ $FORCE -eq 0 ]; then
    echo -e "  ${YELLOW}~ Claude${NC}: $dest already exists (use --force)"; return
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "  [dry-run] cp -r $SKILL_ROOT → $dest"
  else
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -r "$SKILL_ROOT" "$dest"
    # Claude expects root to have SKILL.md, not nested
    if [ ! -f "$dest/SKILL.md" ] && [ -f "$dest/$(basename "$SKILL_ROOT")/SKILL.md" ]; then
      mv "$dest/$(basename "$SKILL_ROOT")"/* "$dest/"
    fi
  fi
  echo -e "  ${GREEN}✓ Claude${NC}:   $dest/SKILL.md"
}

install_codex() {
  local dest="$CODEX_SKILLS/$SKILL_NAME"
  if [ -e "$dest" ] && [ $FORCE -eq 0 ]; then
    echo -e "  ${YELLOW}~ Codex${NC}:  $dest already exists (use --force)"; return
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "  [dry-run] cp -r $SKILL_ROOT → $dest"
  else
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -r "$SKILL_ROOT" "$dest"
  fi
  echo -e "  ${GREEN}✓ Codex${NC}:    $dest/SKILL.md  (SKILL.md format — identical to Claude)"
}

# Convert Claude SKILL.md → OpenCode command format
convert_to_opencode() {
  local src="$1" out="$2" name="$3" desc="$4" body_offset="$5"
  SRC="$src" OUT="$out" NAME="$name" DESC="$desc" BODY_OFFSET="$body_offset" python3 <<'PYEOF'
import os
src_path = os.environ['SRC']
out_path = os.environ['OUT']
name = os.environ['NAME']
desc = os.environ['DESC'].replace('"', '\\"')
body_offset = int(os.environ['BODY_OFFSET'])

with open(src_path) as f:
    content = f.read()
body = content[body_offset:] if body_offset > 0 else content

# Build OpenCode command frontmatter
opencode_fm = f'''---
description: {desc}
argument-hint: <query>
tools:
  read: true
  write: true
  bash: true
  edit: true
---

'''
with open(out_path, 'w') as f:
    f.write(opencode_fm + body)
PYEOF
}

# Convert Claude SKILL.md → Cursor command format
convert_to_cursor() {
  local src="$1" out="$2" name="$3" desc="$4" body_offset="$5"
  SRC="$src" OUT="$out" NAME="$name" DESC="$desc" BODY_OFFSET="$body_offset" python3 <<'PYEOF'
import os
src_path = os.environ['SRC']
out_path = os.environ['OUT']
name = os.environ['NAME']
desc = os.environ['DESC'].replace('"', '\\"')
body_offset = int(os.environ['BODY_OFFSET'])

with open(src_path) as f:
    content = f.read()
body = content[body_offset:] if body_offset > 0 else content

cursor_fm = f'''---
description: {desc}
allowed-tools: [Bash, Read, Write, Edit]
---

'''
with open(out_path, 'w') as f:
    f.write(cursor_fm + body)
PYEOF
}

install_opencode() {
  local dest="$OPENCODE_COMMANDS/$SKILL_NAME.md"
  if [ -e "$dest" ] && [ $FORCE -eq 0 ]; then
    echo -e "  ${YELLOW}~ OpenCode${NC}: $dest already exists (use --force)"; return
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "  [dry-run] convert SKILL.md → OpenCode cmd → $dest"
  else
    mkdir -p "$OPENCODE_COMMANDS"
    convert_to_opencode "$SKILL_MD" "$dest" "$SKILL_NAME" "$DESC" "$BODY_OFFSET"
    # Legacy compat
    [ -d "$OPENCODE_COMMANDS_PLURAL" ] && cp "$dest" "$OPENCODE_COMMANDS_PLURAL/$SKILL_NAME.md"
  fi
  echo -e "  ${GREEN}✓ OpenCode${NC}: $dest  (converted to command format)"
}

install_cursor() {
  local dest="$CURSOR_COMMANDS/$SKILL_NAME.md"
  if [ -e "$dest" ] && [ $FORCE -eq 0 ]; then
    echo -e "  ${YELLOW}~ Cursor${NC}:   $dest already exists (use --force)"; return
  fi
  if [ $DRY_RUN -eq 1 ]; then
    echo "  [dry-run] convert SKILL.md → Cursor cmd → $dest"
  else
    mkdir -p "$CURSOR_COMMANDS"
    convert_to_cursor "$SKILL_MD" "$dest" "$SKILL_NAME" "$DESC" "$BODY_OFFSET"
  fi
  echo -e "  ${GREEN}✓ Cursor${NC}:   $dest  (converted to command format)"
}

echo -e "${BLUE}Installing to:${NC} ${TARGETS[*]}"
echo ""
for t in "${TARGETS[@]}"; do
  case "$t" in
    claude)   install_claude ;;
    codex)    install_codex ;;
    opencode) install_opencode ;;
    cursor)   install_cursor ;;
  esac
done

echo ""
echo -e "${GREEN}═══ Skill '$SKILL_NAME' installed ═══${NC}"
echo ""
echo "  Restart/reload the agent to pick up the new skill."
[ $DRY_RUN -eq 1 ] && echo -e "  ${YELLOW}(dry-run — no files were written)${NC}"
