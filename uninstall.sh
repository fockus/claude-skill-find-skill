#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# claude-skill-find-skill — Multi-agent uninstaller
# Removes find-skill from Claude Code, Codex, OpenCode, Cursor
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SKILL_DIR/.installed-manifest.json"

# Native paths per agent
CC_DEST="$HOME/.claude/skills/find-skill"
CC_FIND_CMD="$HOME/.claude/commands/find-skill.md"
CC_INSTALL_CMD="$HOME/.claude/commands/install-skill.md"
CODEX_DEST="$HOME/.codex/skills/find-skill"
OPENCODE_SINGULAR="$HOME/.config/opencode/command/find-skill.md"
OPENCODE_PLURAL="$HOME/.config/opencode/commands/find-skill.md"
CURSOR_CMD="$HOME/.cursor/commands/find-skill.md"

# Shared components (in CC_DEST)
SHARED_ENV="$CC_DEST/.env"
SHARED_CACHE="$CC_DEST/cache"

echo ""
echo -e "${BOLD}═══ Uninstalling find-skill ═══${NC}"
echo ""

# ─────────────────────────────────────────
# Parse target flag
# ─────────────────────────────────────────
TARGETS=()
KEEP_CACHE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target|-t)
      IFS=',' read -ra REQ <<< "$2"
      TARGETS+=("${REQ[@]}")
      shift 2
      ;;
    --keep-cache)
      KEEP_CACHE=1
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--target TARGET[,TARGET...]] [--keep-cache]

Targets: claude, codex, opencode, cursor, all (default: all)
--keep-cache: don't delete shared catalogue/env (saves marketplace key & 4K skills)
EOF
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      exit 1
      ;;
  esac
done

# Default: all
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("claude" "codex" "opencode" "cursor")
fi
if [[ " ${TARGETS[*]} " == *" all "* ]]; then
  TARGETS=("claude" "codex" "opencode" "cursor")
fi

echo "Will remove from: ${BOLD}${TARGETS[*]}${NC}"
[ $KEEP_CACHE -eq 1 ] && echo "  (shared cache + env will be kept)"
echo ""
echo -n "Proceed? (y/n): "
read -r c
[ "$c" != "y" ] && { echo "Aborted."; exit 0; }

echo ""

# ─────────────────────────────────────────
# Remove per target
# ─────────────────────────────────────────
remove_claude_code() {
  echo -e "${BLUE}→ Claude Code${NC}"
  # Keep shared cache/env unless user opted in
  if [ $KEEP_CACHE -eq 1 ] && [ -d "$CC_DEST" ]; then
    # Remove only SKILL.md and CLAUDE.md, keep cache + .env
    rm -f "$CC_DEST/SKILL.md" "$CC_DEST/CLAUDE.md" "$CC_DEST/README.md" "$CC_DEST/update-skills-catalogue.sh"
    echo -e "  ${GREEN}✓${NC} Removed skill files (kept cache + .env)"
  else
    rm -rf "$CC_DEST"
    echo -e "  ${GREEN}✓${NC} Removed $CC_DEST"
  fi
  rm -f "$CC_FIND_CMD" "$CC_INSTALL_CMD"
  echo -e "  ${GREEN}✓${NC} Removed Claude commands"
}

remove_codex() {
  echo -e "${BLUE}→ Codex${NC}"
  rm -rf "$CODEX_DEST"
  echo -e "  ${GREEN}✓${NC} Removed $CODEX_DEST"
}

remove_opencode() {
  echo -e "${BLUE}→ OpenCode${NC}"
  rm -f "$OPENCODE_SINGULAR" "$OPENCODE_PLURAL"
  echo -e "  ${GREEN}✓${NC} Removed OpenCode command files"
}

remove_cursor() {
  echo -e "${BLUE}→ Cursor${NC}"
  rm -f "$CURSOR_CMD"
  echo -e "  ${GREEN}✓${NC} Removed $CURSOR_CMD"
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    claude)   remove_claude_code ;;
    codex)    remove_codex ;;
    opencode) remove_opencode ;;
    cursor)   remove_cursor ;;
    *)        echo -e "${YELLOW}Unknown target: $t (skipping)${NC}" ;;
  esac
done

# ─────────────────────────────────────────
# Cron + manifest
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Cleanup${NC}"
(crontab -l 2>/dev/null | grep -v "update-skills-catalogue" | crontab -) 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Cleaned cron entries (if any)"

rm -f "$MANIFEST"
echo -e "  ${GREEN}✓${NC} Removed manifest"

echo ""
echo -e "${GREEN}═══ Uninstalled ═══${NC}"
if [ $KEEP_CACHE -eq 1 ]; then
  echo ""
  echo -e "  ${YELLOW}Kept${NC}: $SHARED_CACHE/ and $SHARED_ENV"
  echo "         Re-run install.sh anytime to restore skill files."
fi
echo ""
