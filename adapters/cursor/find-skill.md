---
description: Поиск и установка Claude Code skills / Cursor rules из 14 источников с общим каталогом в ~/.claude/skills/find-skill/cache/catalogue.json
allowed-tools: [Bash, Read, Write, Edit]
---

# Find Skill — поиск скилов (Cursor)

Ты — эксперт по поиску скилов. Каталог: **14 источников**, ~4800 уникальных скилов, ранжирование по GitHub stars.

**Запрос пользователя:** $ARGUMENTS

---

## Этап 0 — Проверить свежесть каталога

```bash
CACHE_FILE="$HOME/.claude/skills/find-skill/cache/catalogue.json"
LAST_UPDATE="$HOME/.claude/skills/find-skill/cache/last_update.txt"

if [ ! -f "$LAST_UPDATE" ] || [ ! -f "$CACHE_FILE" ]; then
  echo "Каталог не инициализирован — запусти update-skills-catalogue.sh"
  exit 1
fi

LAST=$(cat "$LAST_UPDATE")
NOW=$(date +%s)
DIFF=$(( (NOW - LAST) / 86400 ))
if [ "$DIFF" -gt 30 ]; then
  echo "Каталог устарел ($DIFF дней). Обнови: ~/.claude/skills/find-skill/update-skills-catalogue.sh"
fi
```

Скрипт общий для всех агентов: `~/.claude/skills/find-skill/update-skills-catalogue.sh`

---

## Этап 1 — Парсинг аргументов из $ARGUMENTS

| Флаг | Действие |
|---|---|
| `<слово>` | Поисковой запрос |
| `--limit N` | Показать N результатов (default 5) |
| `--page N` | Страница N (default 1) |
| `--all` | Все найденные |
| `--agent <name>` | Фильтр по агенту: `cursor` (default), `claude`, `codex`, `opencode`, `any` |
| `--top N` | Top-N по звёздам |
| `--stats` | Статистика каталога |

**По умолчанию `agent_filter = 'cursor'`** — только скилы совместимые с Cursor. `--agent any` снимает фильтр. Если результатов мало — предложи `--agent any`.

Если запрос пустой — спроси пользователя что ищем.

---

## Этап 2 — Поиск в каталоге

```bash
cat ~/.claude/skills/find-skill/cache/catalogue.json | python3 -c "
import json, sys

data = json.load(sys.stdin)
query = 'QUERY'.lower()
limit = LIMIT
page = PAGE
show_all = SHOW_ALL
agent_filter = 'AGENT_FILTER'  # default 'cursor' for this adapter

SOURCE_PRIORITY = {
    'Anthropic': 60,
    'skills.sh': 30,
    'hesreallyhim': 28,
    'ComposioHQ': 25,
    'vercel-labs': 12,
    'VoltAgent-subagents': 8,
    'VoltAgent': 7,
    'travisvn': 5,
    'BehiSecc': 4,
    'alirezarezvani': 4,
    'heilcheng': 3,
    'daymade': 3,
    'mxyhi': 3,
    'SkillsMP': 3,
}

results = []
for s in data['skills']:
    # Фильтр по агенту
    if agent_filter and agent_filter != 'any':
        skill_agents = s.get('agents', ['claude', 'codex'])
        if agent_filter not in skill_agents:
            continue

    score = 0
    name_l = s['name'].lower()
    desc_l = s.get('description', '').lower()
    tags_l = [t.lower() for t in s.get('tags', [])]

    if query == name_l:
        score = 100
    elif query in name_l:
        score = 50
    elif query in desc_l:
        score = 20
    elif any(query in t for t in tags_l):
        score = 10

    if score > 0:
        source = s.get('source', '')
        source_bonus = SOURCE_PRIORITY.get(source, 0)
        try:
            stars = int(str(s.get('stars', 0) or 0).replace(',','').replace('+',''))
        except:
            stars = 0
        stars_bonus = min(stars / 1000, 20)
        s['_score'] = score + source_bonus + stars_bonus
        s['_stars'] = stars
        results.append(s)

results.sort(key=lambda x: (-x['_score'], -x['_stars']))

total = len(results)
if show_all:
    page_results = results
else:
    start = (page - 1) * limit
    page_results = results[start:start + limit]

print(json.dumps({
    'total': total,
    'showing': len(page_results),
    'page': page if not show_all else 1,
    'limit': limit,
    'agent_filter': agent_filter,
    'results': page_results
}, indent=2, ensure_ascii=False))
"
```

**Агент-фильтр для Cursor**: по умолчанию `agent_filter = 'cursor'`. `--agent any` — весь каталог (~4800 скилов). Для большинства — `skills.sh` источник (единственный мульти-агентный).

---

## Этап 3 — Живой поиск (если < 2 результатов в каталоге)

```bash
source ~/.claude/skills/find-skill/.env 2>/dev/null
if [ -n "$SKILLSMP_API_KEY" ]; then
  curl -s "https://skillsmp.com/api/v1/skills/search?q=QUERY&limit=LIMIT" \
    -H "Authorization: Bearer $SKILLSMP_API_KEY"
fi
```

---

## Этап 4 — Показать результаты

### Уровни доверия (апрель 2026):
```
Anthropic (105K)                              → Официальный
skills.sh (Vercel, ~4K)                       → Официальный каталог
hesreallyhim (39.9K) / ComposioHQ (49K)       → Топ awesome-list
vercel-labs (24K)                             → Курированный
VoltAgent-subagents (15.5K) / VoltAgent (13K) → Курированный
travisvn (10K) / BehiSecc (8K)                → Курированный
alirezarezvani (8K) / heilcheng (3.5K)        → Сообщество-проверенный
daymade / mxyhi                               → Сообщество
SkillsMP                                      → Маркетплейс — проверяй вручную
```

### Компактный формат (до 5):
```
Найдено N скилов по запросу "QUERY":

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. <название> (РЕКОМЕНДОВАНО)
   Источник  : Anthropic        | Доверие: Официальный
   Описание  : <1-2 предложения>
   Звёзды    : <N>
   Repo      : <URL>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Установить? (номер, список, "все", или "нет")
```

### Табличный (6+):
```
Найдено N скилов (стр. PAGE/TOTAL):

| #  | Название       | Источник   | Доверие | Звёзды | Описание        |
|----|----------------|-----------|---------|--------|-----------------|
| 1  | skill-name     | Anthropic | Офиц.   | 105K   | Краткое...      |

Следующая страница: /find-skill QUERY --page NEXT
```

---

## Этап 5 — Установка в Cursor

**Никогда не устанавливать без подтверждения.**

Cursor поддерживает:

**A) User-level commands** (`~/.cursor/commands/<name>.md`) — команды работают глобально во всех проектах:
```bash
SKILL_NAME="<имя>"
REPO_URL="<url>"

# Клонируем skill, берём SKILL.md → конвертируем в Cursor command
TMP=$(mktemp -d)
git clone --depth 1 "$REPO_URL" "$TMP"
if [ -f "$TMP/SKILL.md" ]; then
  # Cursor command format: description + allowed-tools + body
  # Здесь предложи пользователю выбрать: конвертировать в command или оставить как есть
  mkdir -p ~/.cursor/commands
  cp "$TMP/SKILL.md" ~/.cursor/commands/"$SKILL_NAME".md
fi
rm -rf "$TMP"
```

**B) Project rules** (`.cursor/rules/<name>.mdc`) — правила только для текущего проекта:
```bash
mkdir -p .cursor/rules
git clone "$REPO_URL" .cursor/rules/"$SKILL_NAME"
# Переименовать SKILL.md → <name>.mdc с adjusted frontmatter если нужно
```

**Важно**: rules Cursor автоматически применяются к контексту по globs/alwaysApply. Для интерактивных команд — используй `~/.cursor/commands/`.

Если пользователь работает в другом агенте — установить туда:
- Claude Code: `~/.claude/skills/<name>/` (папка)
- Codex: `~/.codex/skills/<name>/` (папка)
- OpenCode: `~/.config/opencode/command/<name>.md` (один файл)

---

## Этап 6 — Подтвердить

После установки:
1. Путь установки
2. Как использовать (`/command-name` или attach rule)
3. Пример использования

---

## Специальные команды

| Запрос | Действие |
|---|---|
| `/find-skill обнови каталог` | Запустить `~/.claude/skills/find-skill/update-skills-catalogue.sh` |
| `/find-skill --stats` | Статистика по источникам |
| `/find-skill --top 20` | Top-20 по звёздам |
| `/find-skill <query> --all` | Все результаты |

---

## Правила

- **Никогда не устанавливать без подтверждения**
- **Сначала кэш, потом API**
- **По умолчанию 5 результатов**
- **Приоритет**: Anthropic (105K) > skills.sh > hesreallyhim (39.9K) > ComposioHQ (49K) > vercel-labs (24K) > VoltAgent-subagents (15.5K) > VoltAgent (13K) > travisvn (10K) > BehiSecc/alirezarezvani (8K) > heilcheng (3.5K) > daymade/mxyhi > SkillsMP
- **Табличный формат при 6+ результатах**
