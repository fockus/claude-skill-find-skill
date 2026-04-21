#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-find-skill — Multi-agent installer
# Targets: Claude Code, Codex, OpenCode, Cursor (14 skill sources)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SKILL_DIR/.installed-manifest.json"

# Shared paths (all targets read from the same cache)
SHARED_ROOT="$HOME/.claude/skills/find-skill"
SHARED_CACHE="$SHARED_ROOT/cache"
SHARED_ENV="$SHARED_ROOT/.env"
SHARED_UPDATE_SCRIPT="$SHARED_ROOT/update-skills-catalogue.sh"

# Native install paths per agent
CC_DEST="$HOME/.claude/skills/find-skill"
CC_COMMANDS="$HOME/.claude/commands"
CODEX_DEST="$HOME/.codex/skills/find-skill"
OPENCODE_COMMAND_SINGULAR="$HOME/.config/opencode/command"
OPENCODE_COMMAND_PLURAL="$HOME/.config/opencode/commands"
CURSOR_COMMANDS="$HOME/.cursor/commands"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

INSTALLED_FILES=()
TARGETS=()

# ─────────────────────────────────────────
# Usage
# ─────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $0 [--target TARGET[,TARGET...]]

Targets:
  claude     Claude Code  (~/.claude/skills/find-skill/)
  codex      OpenAI Codex (~/.codex/skills/find-skill/)
  opencode   OpenCode     (~/.config/opencode/command/find-skill.md)
  cursor     Cursor       (~/.cursor/commands/find-skill.md)
  all        Install to every detected agent

Default: auto-detect installed agents and install to all of them.

Examples:
  $0                               # auto-detect
  $0 --target claude               # Claude Code only
  $0 --target opencode,cursor      # OpenCode + Cursor
  $0 --target all                  # everything regardless of detection
EOF
  exit 0
}

# ─────────────────────────────────────────
# Parse args
# ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target|-t)
      IFS=',' read -ra REQUESTED <<< "$2"
      TARGETS+=("${REQUESTED[@]}")
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      usage
      ;;
  esac
done

# ─────────────────────────────────────────
# Auto-detect if --target not specified
# ─────────────────────────────────────────
if [ ${#TARGETS[@]} -eq 0 ]; then
  echo -e "${BLUE}[auto-detect] Scanning for installed agents...${NC}"
  [ -d "$HOME/.claude" ] && TARGETS+=("claude") && echo -e "  ${GREEN}✓${NC} Claude Code detected"
  [ -d "$HOME/.codex" ] && TARGETS+=("codex") && echo -e "  ${GREEN}✓${NC} Codex detected"
  [ -d "$HOME/.config/opencode" ] && TARGETS+=("opencode") && echo -e "  ${GREEN}✓${NC} OpenCode detected"
  [ -d "$HOME/.cursor" ] && TARGETS+=("cursor") && echo -e "  ${GREEN}✓${NC} Cursor detected"

  if [ ${#TARGETS[@]} -eq 0 ]; then
    echo -e "${RED}No agents detected. Specify --target explicitly.${NC}"
    usage
  fi
  echo ""
fi

# Expand "all"
if [[ " ${TARGETS[*]} " == *" all "* ]]; then
  TARGETS=("claude" "codex" "opencode" "cursor")
fi

# Dedupe & validate
VALID=("claude" "codex" "opencode" "cursor")
DEDUPED=()
for t in "${TARGETS[@]}"; do
  found=0
  for v in "${VALID[@]}"; do [ "$t" = "$v" ] && found=1; done
  if [ $found -eq 0 ]; then
    echo -e "${RED}Invalid target: $t${NC}" >&2
    usage
  fi
  already=0
  # Guard empty-array expansion for bash 3.2 (macOS) under `set -u`.
  for d in ${DEDUPED[@]+"${DEDUPED[@]}"}; do [ "$t" = "$d" ] && already=1; done
  [ $already -eq 0 ] && DEDUPED+=("$t")
done
TARGETS=(${DEDUPED[@]+"${DEDUPED[@]}"})

echo -e "${BOLD}═══ Installing find-skill ═══${NC}"
echo -e "  Targets: ${GREEN}${TARGETS[*]}${NC}"
echo ""

# ─────────────────────────────────────────
# Step 1: Shared components (always)
# ─────────────────────────────────────────
echo -e "${BLUE}[1/5] Shared components${NC}"
mkdir -p "$SHARED_ROOT" "$SHARED_CACHE"

# update-skills-catalogue.sh is the single source of truth
cp "$SKILL_DIR/update-skills-catalogue.sh" "$SHARED_UPDATE_SCRIPT"
chmod +x "$SHARED_UPDATE_SCRIPT"
INSTALLED_FILES+=("$SHARED_UPDATE_SCRIPT")
echo -e "  ${GREEN}✓${NC} Update script: $SHARED_UPDATE_SCRIPT"

# install-skill.sh — universal skill installer for all 4 agents
SHARED_INSTALL_SCRIPT="$SHARED_ROOT/scripts/install-skill.sh"
mkdir -p "$SHARED_ROOT/scripts"
cp "$SKILL_DIR/scripts/install-skill.sh" "$SHARED_INSTALL_SCRIPT"
chmod +x "$SHARED_INSTALL_SCRIPT"
INSTALLED_FILES+=("$SHARED_INSTALL_SCRIPT")
echo -e "  ${GREEN}✓${NC} Install script: $SHARED_INSTALL_SCRIPT"

# .env for API keys (shared across all agents)
touch "$SHARED_ENV"
chmod 600 "$SHARED_ENV"
INSTALLED_FILES+=("$SHARED_ENV")
echo -e "  ${GREEN}✓${NC} Shared env: $SHARED_ENV"

# ─────────────────────────────────────────
# Step 2: SkillsMP API key (optional, one-time)
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/5] Marketplace API key (optional)${NC}"
if grep -q "SKILLSMP_API_KEY=" "$SHARED_ENV" 2>/dev/null; then
  echo -e "  ${YELLOW}~${NC} SkillsMP key already configured (skipping)"
else
  echo "  SkillsMP is an optional community marketplace (+352 skills)."
  echo "  The local catalogue (4800+ skills) works fine without a key."
  echo ""
  echo -e "  ${BOLD}Get a free key:${NC} https://skillsmp.com  →  sign in  →  Settings → API keys"
  echo "  The key is stored only in: $SHARED_ENV  (chmod 600, never committed)"
  echo ""
  echo -n "  Paste SkillsMP API key (or press Enter to skip): "
  read -r skillsmp_key
  if [ -n "$skillsmp_key" ]; then
    echo "export SKILLSMP_API_KEY=\"$skillsmp_key\"" >> "$SHARED_ENV"
    echo -e "  ${GREEN}✓${NC} Saved. The agent will automatically source this file when searching."
    echo -e "    To change later: edit $SHARED_ENV"
  else
    echo -e "  ${YELLOW}~${NC} Skipped. To add later:"
    echo "      echo 'export SKILLSMP_API_KEY=\"YOUR_KEY\"' >> $SHARED_ENV"
  fi
fi

# ─────────────────────────────────────────
# Step 3: Per-target install
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[3/5] Agent-specific install${NC}"

install_claude_code() {
  echo -e "  ${BOLD}→ Claude Code${NC}"
  mkdir -p "$CC_DEST" "$CC_COMMANDS"
  cp "$SKILL_DIR/SKILL.md" "$CC_DEST/SKILL.md"
  cp "$SKILL_DIR/CLAUDE.md" "$CC_DEST/CLAUDE.md" 2>/dev/null || true
  INSTALLED_FILES+=("$CC_DEST/SKILL.md")
  # Commands
  for f in "$SKILL_DIR"/commands/*.md; do
    [ -f "$f" ] || continue
    cp "$f" "$CC_COMMANDS/$(basename "$f")"
    INSTALLED_FILES+=("$CC_COMMANDS/$(basename "$f")")
  done
  echo -e "    ${GREEN}✓${NC} Skill:    $CC_DEST/SKILL.md"
  echo -e "    ${GREEN}✓${NC} Commands: $CC_COMMANDS/find-skill.md, install-skill.md"
}

install_codex() {
  echo -e "  ${BOLD}→ Codex${NC}"
  mkdir -p "$CODEX_DEST"
  # Codex uses same SKILL.md format but with codex-specific default agent filter
  cp "$SKILL_DIR/adapters/codex/SKILL.md" "$CODEX_DEST/SKILL.md"
  INSTALLED_FILES+=("$CODEX_DEST/SKILL.md")
  echo -e "    ${GREEN}✓${NC} Skill: $CODEX_DEST/SKILL.md (codex-default filter)"
}

install_opencode() {
  echo -e "  ${BOLD}→ OpenCode${NC}"
  mkdir -p "$OPENCODE_COMMAND_SINGULAR"
  for cmd in find-skill install-skill; do
    cp "$SKILL_DIR/adapters/opencode/$cmd.md" "$OPENCODE_COMMAND_SINGULAR/$cmd.md"
    INSTALLED_FILES+=("$OPENCODE_COMMAND_SINGULAR/$cmd.md")
    echo -e "    ${GREEN}✓${NC} Command: $OPENCODE_COMMAND_SINGULAR/$cmd.md"
    # Legacy compat path
    if [ -d "$OPENCODE_COMMAND_PLURAL" ]; then
      cp "$SKILL_DIR/adapters/opencode/$cmd.md" "$OPENCODE_COMMAND_PLURAL/$cmd.md"
      INSTALLED_FILES+=("$OPENCODE_COMMAND_PLURAL/$cmd.md")
    fi
  done
}

install_cursor() {
  echo -e "  ${BOLD}→ Cursor${NC}"
  mkdir -p "$CURSOR_COMMANDS"
  for cmd in find-skill install-skill; do
    cp "$SKILL_DIR/adapters/cursor/$cmd.md" "$CURSOR_COMMANDS/$cmd.md"
    INSTALLED_FILES+=("$CURSOR_COMMANDS/$cmd.md")
    echo -e "    ${GREEN}✓${NC} Command: $CURSOR_COMMANDS/$cmd.md (user-level)"
  done
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    claude)   install_claude_code ;;
    codex)    install_codex ;;
    opencode) install_opencode ;;
    cursor)   install_cursor ;;
  esac
done

# ─────────────────────────────────────────
# Step 4: Initial catalogue
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[4/5] Skill catalogue${NC}"
if [ -f "$SHARED_CACHE/catalogue.json" ]; then
  COUNT=$(python3 -c "import json; print(json.load(open('$SHARED_CACHE/catalogue.json')).get('total', 0))" 2>/dev/null || echo "?")
  echo -e "  ${YELLOW}~${NC} Catalogue exists ($COUNT skills) — skipping fetch"
else
  echo -n "  Fetch skill catalogue now? (y/n): "
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    "$SHARED_UPDATE_SCRIPT" 2>&1 | tail -20 \
      && echo -e "  ${GREEN}✓${NC} Catalogue fetched" \
      || echo -e "  ${YELLOW}~${NC} Fetch failed (run manually later)"
  else
    echo -e "  ${YELLOW}~${NC} Skipped. Run later: $SHARED_UPDATE_SCRIPT"
  fi
fi

# ─────────────────────────────────────────
# Step 5: Manifest
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/5] Manifest${NC}"
INSTALLED_FILES_STR="$(printf '%s\n' "${INSTALLED_FILES[@]}")" \
TARGETS_STR="$(IFS=','; echo "${TARGETS[*]}")" \
MANIFEST_PATH="$MANIFEST" \
INSTALL_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
python3 <<'PYEOF' 2>/dev/null || echo "  Manifest skipped"
import json, os
files = [f for f in os.environ.get("INSTALLED_FILES_STR", "").split("\n") if f]
manifest = {
    "installed_at": os.environ["INSTALL_DATE"],
    "skill": "claude-skill-find-skill",
    "targets": os.environ["TARGETS_STR"].split(","),
    "files": sorted(set(files))
}
with open(os.environ["MANIFEST_PATH"], "w") as f:
    json.dump(manifest, f, indent=2)
print(f"  Manifest: {os.environ['MANIFEST_PATH']}")
PYEOF

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}═══ find-skill installed ═══${NC}"
echo ""
for t in "${TARGETS[@]}"; do
  case "$t" in
    claude)   echo -e "  ${BOLD}Claude Code${NC}: /find-skill <query>" ;;
    codex)    echo -e "  ${BOLD}Codex${NC}:       /find-skill <query>" ;;
    opencode) echo -e "  ${BOLD}OpenCode${NC}:    /find-skill <query>" ;;
    cursor)   echo -e "  ${BOLD}Cursor${NC}:      /find-skill <query>" ;;
  esac
done
echo ""
echo "  Shared catalogue: $SHARED_CACHE/catalogue.json"
echo "  Shared update:    $SHARED_UPDATE_SCRIPT"
echo "  Uninstall:        $SKILL_DIR/uninstall.sh"
echo ""
