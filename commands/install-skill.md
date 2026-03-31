---
description: "Install a Claude Code skill from GitHub"
allowed-tools: [Bash, Read, Write, Glob]
---

# /install-skill

Install a Claude Code skill from a GitHub repository.

## Input

User provides one of:
- GitHub URL: `https://github.com/owner/repo`
- Short form: `owner/repo`
- Skill name from catalogue: `skill-name`

## Workflow

### Step 1 — Resolve source

```
If input is a full URL:
  REPO_URL = input
  REPO_NAME = basename of URL (strip .git if present)

If input is owner/repo:
  REPO_URL = https://github.com/{input}
  REPO_NAME = repo part

If input is a skill name (no / or http):
  Search ~/.claude/skills/find-skill/cache/catalogue.json for matching skill
  If found → extract repo URL
  If not found → tell user to run /find-skill first
```

### Step 2 — Pre-flight checks

```bash
# Check if already installed
DEST="$HOME/.claude/skills/$REPO_NAME"
if [ -d "$DEST" ]; then
  echo "⚠️  $REPO_NAME already installed at $DEST"
  echo "To reinstall: rm -rf $DEST && /install-skill $INPUT"
  # ASK user: reinstall or skip?
fi

# Check if git is available
command -v git >/dev/null || { echo "ERROR: git not found"; exit 1; }
```

### Step 3 — Clone

```bash
git clone "$REPO_URL" "$DEST"
```

If clone fails — report error and stop.

### Step 4 — Detect and run installer

```bash
cd "$DEST"

if [ -f "install.sh" ]; then
  chmod +x install.sh
  [ -f "uninstall.sh" ] && chmod +x uninstall.sh
  echo "Running install.sh..."
  ./install.sh
elif [ -f "SKILL.md" ]; then
  echo "No install.sh found. Skill is ready (SKILL.md detected)."
  echo "Skills with just SKILL.md are auto-detected by Claude Code."
else
  echo "⚠️  No install.sh or SKILL.md found. This may not be a Claude Code skill."
fi
```

### Step 5 — Verify

```bash
# Check what was installed
echo ""
echo "=== Installed ==="
echo "  Location: $DEST"
ls -1 "$DEST/" | head -15

# Check for SKILL.md
if [ -f "$DEST/SKILL.md" ]; then
  echo ""
  echo "=== Skill description ==="
  head -5 "$DEST/SKILL.md"
fi

# Check for commands
if ls "$DEST"/commands/*.md 1>/dev/null 2>&1; then
  echo ""
  echo "=== Commands ==="
  for cmd in "$DEST"/commands/*.md; do
    echo "  /$(basename "$cmd" .md)"
  done
fi
```

### Step 6 — Report

Show:
1. Where skill was installed
2. Available commands (if any)
3. How to use it
4. How to uninstall: `cd $DEST && ./uninstall.sh` or `rm -rf $DEST`

## Examples

```
/install-skill fockus/claude-skill-memory-bank
/install-skill fockus/claude-skill-build
/install-skill fockus/claude-skill-find-skill
/install-skill https://github.com/anthropics/claude-code-router
/install-skill memory-bank    # searches catalogue
```

## Rules

- **Never install without showing the user what will happen first**
- **Always clone to `~/.claude/skills/<repo-name>/`**
- **Always chmod +x install.sh before running**
- **If install.sh requires dependencies, warn the user**
- **Show uninstall instructions after install**
