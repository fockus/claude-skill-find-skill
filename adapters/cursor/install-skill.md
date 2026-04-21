---
description: Установка скила из GitHub в любого из 4 агентов (Claude, Codex, OpenCode, Cursor) с авто-конвертацией формата. По умолчанию — Cursor.
allowed-tools: [Bash, Read, Write, Edit]
---

# /install-skill (Cursor)

Устанавливает скил из GitHub в Cursor (по умолчанию) или любой другой агент.

**Аргументы:** $ARGUMENTS

## Workflow

### Этап 1 — Парсинг аргументов из $ARGUMENTS

| Аргумент | Значение |
|---|---|
| `<source>` | `owner/repo`, URL, или имя из каталога — **обязательный** |
| `--target <list>` | Агенты через запятую. Default: `cursor` |
| `--name NAME` | Для mono-repo — имя sub-skill-а |
| `--force` | Перезаписать существующий скил |
| `--dry-run` | Показать план без записи |

### Этап 2 — Confirm

Перед запуском покажи:
- Resolved URL
- Target agents
- Warn если скил уже установлен (`~/.cursor/commands/<name>.md`)

Спроси подтверждение.

### Этап 3 — Вызов shared installer

```bash
~/.claude/skills/find-skill/scripts/install-skill.sh \
  "$SKILL_SRC" \
  --target "$TARGET" \
  [--name "$NAME"] \
  [--force]
```

Для Cursor target скрипт:
- Клонирует репо в temp
- Находит SKILL.md (до глубины 4)
- **Конвертирует** frontmatter → Cursor command format:
  ```yaml
  ---
  description: <из SKILL.md>
  allowed-tools: [Bash, Read, Write, Edit]
  ---
  ```
- Устанавливает в `~/.cursor/commands/<name>.md`

### Этап 4 — Report

После установки:
- Путь куда установлено
- "Перезапусти Cursor чтобы команда появилась в `/<name>`"

## Примеры

```
/install-skill fockus/claude-skill-memory-bank
  → ~/.cursor/commands/memory-bank.md (converted from SKILL.md)

/install-skill revealjs-skill --target all
  → во все 4 агента

/install-skill obra/superpowers-skills --name brainstorming
  → из mono-repo берёт brainstorming/SKILL.md
```

## Правила

- **Никогда не устанавливать без подтверждения**
- **Показывать diff формата при конвертации**
- **Предупреждать если скил уже установлен** — не перезаписывать без `--force`
- **После установки — перезапустить Cursor**

## Где лежит shared installer

`~/.claude/skills/find-skill/scripts/install-skill.sh` — общий скрипт для всех 4 агентов.
