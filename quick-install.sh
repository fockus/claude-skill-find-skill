#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# quick-install.sh — one-liner installer for find-skill
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/fockus/claude-skill-find-skill/main/quick-install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/fockus/claude-skill-find-skill/main/quick-install.sh | bash -s -- --target claude
#
# Or: download then run
#   bash <(curl -sSL .../quick-install.sh) --target opencode,cursor
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

REPO_URL="${FIND_SKILL_REPO:-https://github.com/fockus/claude-skill-find-skill.git}"
REPO_BRANCH="${FIND_SKILL_BRANCH:-main}"
INSTALL_DIR="$HOME/.claude/skills/claude-skill-find-skill"

echo ""
echo -e "${BOLD}═══ find-skill — quick install ═══${NC}"
echo ""
echo "  Multi-agent skill discovery (Claude Code, Codex, OpenCode, Cursor)"
echo "  14 sources · ~4800 skills · shared catalogue"
echo ""

# ─────────────────────────────────────────
# Prerequisites
# ─────────────────────────────────────────
command -v git >/dev/null 2>&1 || {
  echo -e "${RED}Error:${NC} git is not installed. Install git and re-run." >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo -e "${RED}Error:${NC} python3 is not installed. Install Python 3 and re-run." >&2
  exit 1
}

# ─────────────────────────────────────────
# Fetch / update repo
# ─────────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "${BLUE}→ Updating existing checkout at $INSTALL_DIR${NC}"
  git -C "$INSTALL_DIR" fetch --quiet origin "$REPO_BRANCH"
  git -C "$INSTALL_DIR" reset --hard --quiet "origin/$REPO_BRANCH"
else
  echo -e "${BLUE}→ Cloning repo to $INSTALL_DIR${NC}"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --quiet --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR"/install.sh "$INSTALL_DIR"/uninstall.sh \
         "$INSTALL_DIR"/update-skills-catalogue.sh \
         "$INSTALL_DIR"/scripts/install-skill.sh 2>/dev/null || true

# ─────────────────────────────────────────
# Run install.sh with forwarded args
# ─────────────────────────────────────────
echo ""
echo -e "${BLUE}→ Running installer${NC}"
echo ""
exec "$INSTALL_DIR/install.sh" "$@"
