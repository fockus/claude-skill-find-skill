---
name: find-skill
description: Находит и устанавливает Claude Code Skills для проекта. 14 источников, ранжирование по звёздам GitHub. Примеры: "найди скил для Docker", "поищи скилы для тестирования", "покажи все скилы по react". Поддерживает параметры: limit (сколько показать), page (пагинация), --all (показать все).
---

# Find Skill — поиск и установка скилов

Ты — эксперт по поиску скилов с локальным каталогом (14 источников, ранжирование по GitHub stars).

---

## Параметры вызова

Скил принимает аргументы в свободной форме. Парси их так:

| Формат | Пример | Значение |
|--------|--------|----------|
| `<запрос>` | `docker` | Поиск по ключевому слову, показать top 3 |
| `<запрос> --limit N` | `react --limit 10` | Показать N результатов |
| `<запрос> --all` | `design --all` | Показать ВСЕ найденные результаты |
| `<запрос> --page N` | `python --limit 5 --page 2` | Страница N (по `limit` на страницу) |
| `<запрос> --agent <name>` | `docker --agent cursor` | Фильтр по агенту: `claude`, `codex`, `opencode`, `cursor`, `any` |
| `--top N` | `--top 20` | Показать top-N скилов по звёздам из всего каталога |
| `--stats` | `--stats` | Статистика каталога по источникам и агентам |
| `--category <cat>` | `--category design` | Все скилы категории |

**Значения по умолчанию:** limit=5, page=1, **agent=codex** (текущий агент — Codex).

**Важно про `--agent`:** по умолчанию показываются только скилы совместимые с текущим агентом (Claude Code). Используй `--agent any` чтобы снять фильтр и увидеть весь каталог, `--agent cursor` чтобы найти скилы только для Cursor и т.д.

---

## Этап 0 — Проверить свежесть каталога

```bash
CACHE_FILE="$HOME/.claude/skills/find-skill/cache/catalogue.json"
LAST_UPDATE="$HOME/.claude/skills/find-skill/cache/last_update.txt"

if [ ! -f "$LAST_UPDATE" ]; then
  echo "Каталог не инициализирован — нужно обновить"
  NEEDS_UPDATE=true
else
  LAST=$(cat "$LAST_UPDATE")
  NOW=$(date +%s)
  DIFF=$(( (NOW - LAST) / 86400 ))
  if [ "$DIFF" -gt 30 ]; then
    echo "Каталог устарел ($DIFF дней) — нужно обновить"
    NEEDS_UPDATE=true
  else
    echo "Каталог актуален (обновлён $DIFF дней назад)"
    NEEDS_UPDATE=false
  fi
fi
```

Если `NEEDS_UPDATE=true` — запусти `~/.claude/skills/find-skill/update-skills-catalogue.sh`.

---

## Этап 1 — Понять запрос

Если запрос неясен — задай 1-2 вопроса:
- Какой стек/язык/фреймворк?
- Для какой конкретной задачи?

Если запрос ясен — сразу к этапу 2.

---

## Этап 2 — Поиск в локальном каталоге

```bash
cat ~/.claude/skills/find-skill/cache/catalogue.json | \
  python3 -c "
import json, sys, re

data = json.load(sys.stdin)
query = 'QUERY'.lower()
limit = LIMIT        # заменить на число из параметра
page = PAGE          # заменить на число из параметра
show_all = SHOW_ALL  # True/False
agent_filter = 'AGENT_FILTER'  # 'claude', 'codex', 'opencode', 'cursor', 'any'

# Приоритет источников — баллы пропорциональны звёздам на GitHub (апрель 2026)
SOURCE_PRIORITY = {
    'Anthropic': 60,              # 105K stars — официальные скилы Anthropic
    'skills.sh': 30,              # Vercel-curated каталог, ~4K скилов
    'hesreallyhim': 28,           # 39.9K stars — топ awesome-list
    'ComposioHQ': 25,             # 49K stars — курированный список
    'vercel-labs': 12,            # 24K stars — Vercel agent skills
    'VoltAgent-subagents': 8,     # 15.5K stars — Claude Code subagents
    'VoltAgent': 7,               # 13K stars — awesome agent skills
    'travisvn': 5,                # 10K stars — курированный список
    'BehiSecc': 4,                # 8K stars — курированный список
    'alirezarezvani': 4,          # 8K stars — большая коллекция
    'heilcheng': 3,               # 3.5K stars — awesome agent skills
    'daymade': 3,                 # 744 stars — production-ready коллекция
    'mxyhi': 3,                   # 188 stars — ok-skills
    'SkillsMP': 3,                # Маркетплейс (много, но менее проверены)
}

# Поиск: имя, описание, теги + фильтр по агенту
results = []
for s in data['skills']:
    # Фильтр по агенту (если agent_filter != 'any')
    if agent_filter and agent_filter != 'any':
        skill_agents = s.get('agents', ['claude', 'codex'])  # legacy default
        if agent_filter not in skill_agents:
            continue

    score = 0
    name_l = s['name'].lower()
    desc_l = s.get('description', '').lower()
    tags_l = [t.lower() for t in s.get('tags', [])]

    # Релевантность запросу
    if query == name_l:
        score = 100
    elif query in name_l:
        score = 50
    elif query in desc_l:
        score = 20
    elif any(query in t for t in tags_l):
        score = 10

    if score > 0:
        # Бонус за источник (приоритет доверия)
        source = s.get('source', '')
        source_bonus = SOURCE_PRIORITY.get(source, 0)

        # Бонус за звёзды (макс +20)
        try:
            stars = int(str(s.get('stars', 0) or 0).replace(',','').replace('+',''))
        except:
            stars = 0
        stars_bonus = min(stars / 1000, 20)

        s['_score'] = score + source_bonus + stars_bonus
        s['_stars'] = stars
        s['_source_rank'] = source_bonus
        results.append(s)

# Сортировка: score desc (включает source + stars), затем stars desc
results.sort(key=lambda x: (-x['_score'], -x['_stars']))

total = len(results)
if show_all:
    page_results = results
else:
    start = (page - 1) * limit
    page_results = results[start:start + limit]

total_pages = (total + limit - 1) // limit if not show_all else 1

output = {
    'total': total,
    'showing': len(page_results),
    'page': page if not show_all else 1,
    'total_pages': total_pages,
    'limit': limit,
    'agent_filter': agent_filter,
    'results': page_results
}
print(json.dumps(output, indent=2, ensure_ascii=False))
"
```

**Как использовать `agent_filter`:**
- По умолчанию для этого файла: `agent_filter = 'claude'` (мы в Claude Code)
- Если пользователь указал `--agent any` — показать весь каталог (agent_filter = 'any')
- Если указал `--agent cursor|codex|opencode` — подставить это значение
- В `--stats` отображай распределение по агентам

---

## Этап 3 — Живой поиск (если в каталоге < 2 результатов)

### SkillsMP API:
```bash
source "$HOME/.claude/skills/find-skill/.env" 2>/dev/null

# Поиск по ключевому слову
curl -s "https://skillsmp.com/api/v1/skills/search?q=QUERY&limit=LIMIT" \
  -H "Authorization: Bearer $SKILLSMP_API_KEY"

# AI семантический поиск
curl -s "https://skillsmp.com/api/v1/skills/ai-search?q=QUERY+CONTEXT" \
  -H "Authorization: Bearer $SKILLSMP_API_KEY"
```

---

## Этап 4 — Показать результаты

**Никогда не устанавливать без подтверждения.**

Формат вывода зависит от количества:

### Уровни доверия (по источнику, звёзды апрель 2026):
```
Anthropic (105K)                              → Официальный (зелёный)
skills.sh (Vercel-curated, ~4K entries)       → Официальный каталог (зелёный)
hesreallyhim (39.9K) / ComposioHQ (49K)       → Топ awesome-list (зелёный)
vercel-labs (24K)                             → Курированный (жёлтый)
VoltAgent-subagents (15.5K) / VoltAgent (13K) → Курированный (жёлтый)
travisvn (10K) / BehiSecc (8K)                → Курированный (жёлтый)
alirezarezvani (8K) / heilcheng (3.5K)        → Сообщество-проверенный (оранжевый)
daymade (744) / mxyhi (188)                   → Сообщество (оранжевый)
SkillsMP                                      → Маркетплейс (серый, проверять вручную)
```

### Компактный (до 5 результатов):
```
Найдено N скилов по запросу "QUERY":

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. [название] (РЕКОМЕНДОВАНО)
   Источник  : Anthropic        | Доверие: Официальный
   Описание  : [1-2 предложения]
   Звёзды    : [N]
   Repo      : [URL]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. [название]
   Источник  : SkillsMP         | Доверие: Маркетплейс — проверь repo
   ...

Установить? (1, 2, все, или нет)
```

### Табличный (6+ результатов):
```
Найдено N скилов по запросу "QUERY" (стр. PAGE/TOTAL_PAGES):

| #  | Название          | Источник   | Доверие | Звёзды | Описание (кратко)      |
|----|-------------------|-----------|---------|--------|------------------------|
| 1  | skill-name        | Anthropic | Офиц.   | 9600   | Краткое описание...    |
| 2  | another-skill     | travisvn  | Курир.  | 5600   | Краткое описание...    |
| 3  | some-skill        | SkillsMP  | Маркет. | 120    | Краткое описание...    |

Страница PAGE из TOTAL_PAGES. Следующая: /find-skill QUERY --page NEXT
Установить? (номер, диапазон 1-3, все, или нет)
```

Результаты автоматически отсортированы: сначала официальные и курированные, затем community, в конце маркетплейс. При одинаковом источнике — по звёздам.

---

## Этап 5 — Установить после подтверждения

```bash
mkdir -p ~/.claude/skills
git clone [REPO_URL] ~/.claude/skills/[SKILL_NAME]
echo "Skill [SKILL_NAME] установлен"

# Проверка
ls ~/.claude/skills/[SKILL_NAME]/
head -10 ~/.claude/skills/[SKILL_NAME]/SKILL.md
```

---

## Этап 6 — Подтвердить и объяснить

После установки:
1. Где установлен скил
2. Как активировать (`/skill-name` или автоматически)
3. Пример использования в текущем проекте

---

## Специальные команды

| Запрос | Действие |
|--------|----------|
| `обнови каталог` | Запустить `update-skills-catalogue.sh` |
| `когда обновлялся каталог?` | Показать дату из `last_update.txt` |
| `покажи весь каталог` | Все скилы по категориям |
| `--top 20` | Top-20 по звёздам |
| `--stats` | Статистика по источникам |
| `react --all` | Все скилы по запросу |
| `python --limit 10 --page 2` | Стр. 2 по 10 результатов |

---

## Правила

- **Никогда не устанавливать без подтверждения**
- **Сначала кэш, потом API** (экономим 500 req/день)
- **По умолчанию 5 результатов**, но пользователь может запросить больше
- **Сигнализировать риски** если источник неизвестен
- **Приоритет**: Anthropic (105K) > skills.sh (Vercel-catalog) > hesreallyhim (39.9K) > ComposioHQ (49K) > vercel-labs (24K) > VoltAgent-subagents (15.5K) > VoltAgent (13K) > travisvn (10K) > BehiSecc/alirezarezvani (8K) > heilcheng (3.5K) > daymade/mxyhi > SkillsMP
- **Табличный формат** при 6+ результатах для компактности

---

## Деактивация / удаление

### Временно отключить
```bash
mv ~/.claude/skills/find-skill ~/.claude/skills/find-skill-disabled
```

### Включить обратно
```bash
mv ~/.claude/skills/find-skill-disabled ~/.claude/skills/find-skill
```

### Остановить автообновление (cron)
```bash
crontab -l | grep -v "update-skills-catalogue" | crontab -
```

### Полностью удалить
```bash
crontab -l | grep -v "update-skills-catalogue" | crontab -
rm -rf ~/.claude/skills/find-skill
```
