---
description: Установка скила из GitHub в любого из 4 агентов (Claude, Codex, OpenCode, Cursor) с авто-конвертацией формата. По умолчанию — OpenCode.
argument-hint: <owner/repo | url | catalogue-name> [--target agents] [--name sub] [--force]
tools:
  read: true
  write: true
  bash: true
  edit: true
---

# /install-skill (OpenCode)

Устанавливает скил из GitHub в OpenCode (по умолчанию) или любой другой агент.

**Аргументы:** `$ARGUMENTS`

## Workflow

### Этап 1 — Парсинг аргументов из `$ARGUMENTS`

| Аргумент | Значение |
|---|---|
| `<source>` | `owner/repo`, URL, или имя из каталога — **обязательный** |
| `--target <list>` | Список агентов через запятую. Default: `opencode` |
| `--name NAME` | Для mono-repo — имя sub-skill-а |
| `--force` | Перезаписать существующий скил |
| `--dry-run` | Показать план без записи |

Если source не передан — спроси пользователя.

### Этап 2 — Confirm

Перед запуском покажи:
- Resolved URL
- Target agents
- Warn если скил уже установлен в target paths:
  - `~/.config/opencode/command/<name>.md`
  - `~/.claude/skills/<name>/` (для claude target)
  - и т.д.

Спроси подтверждение: "Install `<name>` into `<targets>`? (y/n)"

### Этап 3 — Вызов shared installer

```bash
~/.claude/skills/find-skill/scripts/install-skill.sh \
  "$SKILL_SRC" \
  --target "$TARGET" \
  [--name "$NAME"] \
  [--force]
```

Скрипт сам:
- Клонирует репо в temp
- Находит SKILL.md (рекурсивно до глубины 4 — для mono-repos)
- Парсит frontmatter (name, description)
- Для OpenCode: **конвертирует** SKILL.md frontmatter → OpenCode command format:
  ```yaml
  ---
  description: <из SKILL.md>
  argument-hint: <query>
  tools: { read: true, write: true, bash: true, edit: true }
  ---
  ```
- Устанавливает в `~/.config/opencode/command/<name>.md` (и `commands/` для legacy compat)

### Этап 4 — Report

После установки покажи:
- Путь куда установлено
- Какой формат (native или конвертированный)
- "Перезапусти OpenCode чтобы команда появилась в `/<name>`"

## Примеры

```
/install-skill fockus/claude-skill-memory-bank
  → ~/.config/opencode/command/memory-bank.md (converted from SKILL.md)

/install-skill revealjs-skill --target all
  → во все 4 агента

/install-skill obra/superpowers-skills --name brainstorming
  → из mono-repo берёт brainstorming/SKILL.md
```

## Правила

- **Никогда не устанавливать без подтверждения**
- **Показывать diff формата при конвертации** (especially если SKILL.md содержал что-то нестандартное)
- **Предупреждать если скил уже установлен** — не перезаписывать без `--force`
- **После установки — перезапустить OpenCode** чтобы команда подхватилась

## Где лежит shared installer

`~/.claude/skills/find-skill/scripts/install-skill.sh` — общий скрипт для всех 4 агентов. Запусти `--help` для полной справки.
