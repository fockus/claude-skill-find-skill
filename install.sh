#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-find-skill — Installer
# Skill discovery from 12+ sources with local catalogue
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MANIFEST="$SKILL_DIR/.installed-manifest.json"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

INSTALLED_FILES=()

echo ""
echo -e "${BOLD}═══ Installing claude-skill-find-skill ═══${NC}"
echo ""
echo "  Discover and install Claude Code skills from 12+ sources."
echo "  Sources: Anthropic, ComposioHQ, vercel-labs, VoltAgent, travisvn, SkillsMP, etc."
echo ""

# ═══ Step 1: Copy skill files ═══
echo -e "${BLUE}[1/4] Skill files${NC}"
FS_DEST="$CLAUDE_DIR/skills/find-skill"
mkdir -p "$FS_DEST/cache"

for f in SKILL.md CLAUDE.md update-skills-catalogue.sh; do
  if [ -f "$SKILL_DIR/$f" ]; then
    cp "$SKILL_DIR/$f" "$FS_DEST/$f"
    [[ "$f" == *.sh ]] && chmod +x "$FS_DEST/$f"
    INSTALLED_FILES+=("$FS_DEST/$f")
  fi
done
echo -e "  ${GREEN}✓${NC} Skill files copied"

# Copy commands
mkdir -p "$CLAUDE_DIR/commands"
for f in "$SKILL_DIR"/commands/*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$CLAUDE_DIR/commands/$(basename "$f")"
  INSTALLED_FILES+=("$CLAUDE_DIR/commands/$(basename "$f")")
done
echo -e "  ${GREEN}✓${NC} Commands installed"

# ═══ Step 2: API Key setup ═══
echo -e "${BLUE}[2/4] Marketplace API keys${NC}"
echo ""
echo "  Find-skill searches local catalogue first (free, fast)."
echo "  For expanded results, you can add marketplace API keys."
echo ""

ENV_FILE="$FS_DEST/.env"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

# SkillsMP API key
echo -e "  ${BOLD}SkillsMP${NC} — community skill marketplace (skillsmp.com)"
echo -n "  Enter SkillsMP API key (or press Enter to skip): "
read -r skillsmp_key
if [ -n "$skillsmp_key" ]; then
  echo "SKILLSMP_API_KEY=$skillsmp_key" >> "$ENV_FILE"
  echo -e "  ${GREEN}✓${NC} SkillsMP key saved"
else
  echo -e "  ${YELLOW}~${NC} Skipped (local catalogue still works)"
fi

echo ""
INSTALLED_FILES+=("$ENV_FILE")

# ═══ Step 3: Initial catalogue ═══
echo -e "${BLUE}[3/4] Skill catalogue${NC}"
echo -n "  Fetch skill catalogue now? (y/n): "
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
  if [ -x "$FS_DEST/update-skills-catalogue.sh" ]; then
    "$FS_DEST/update-skills-catalogue.sh" 2>/dev/null \
      && echo -e "  ${GREEN}✓${NC} Catalogue updated ($(wc -l < "$FS_DEST/cache/catalogue.json" 2>/dev/null || echo '?') lines)" \
      || echo -e "  ${YELLOW}~${NC} Fetch failed (will work without cache)"
  fi
else
  echo -e "  ${YELLOW}~${NC} Skipped. Run later: ~/.claude/skills/find-skill/update-skills-catalogue.sh"
fi

# ═══ Step 4: Manifest ═══
echo -e "${BLUE}[4/4] Manifest${NC}"
INSTALLED_FILES_STR="$(printf '%s\n' "${INSTALLED_FILES[@]}")" \
MANIFEST_PATH="$MANIFEST" \
INSTALL_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
python3 << 'PYEOF' 2>/dev/null || echo '  Manifest skipped'
import json, os
files = [f for f in os.environ.get("INSTALLED_FILES_STR", "").split("\n") if f]
manifest = {
    "installed_at": os.environ["INSTALL_DATE"],
    "skill": "claude-skill-find-skill",
    "files": list(set(files))
}
with open(os.environ["MANIFEST_PATH"], "w") as f:
    json.dump(manifest, f, indent=2)
print("  Manifest saved")
PYEOF

echo ""
echo -e "${GREEN}═══ Find Skill installed ═══${NC}"
echo ""
echo "  Usage: /find-skill <query>"
echo "  Examples: /find-skill docker, /find-skill testing"
echo "  Uninstall: $SKILL_DIR/uninstall.sh"
echo ""
