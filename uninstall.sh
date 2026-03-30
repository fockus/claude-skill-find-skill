#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "\n${BOLD}═══ Uninstalling claude-skill-find-skill ═══${NC}\n"
echo -n "Remove find-skill? (y/n): "; read -r c; [ "$c" != "y" ] && exit 0

(crontab -l 2>/dev/null | grep -v "update-skills-catalogue" | crontab -) 2>/dev/null || true
echo "  Cleaned cron entries (if any)"

rm -rf "$HOME/.claude/skills/find-skill"
rm -f "$(cd "$(dirname "$0")" && pwd)/.installed-manifest.json"

echo -e "\n${GREEN}═══ Uninstalled ═══${NC}\n"
