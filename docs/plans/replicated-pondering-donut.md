# Plan: Powertools Usage Tracking via Claude Code Hooks

## Context

Нет способа узнать, как Claude Code использует установленные powertools. Нужна наблюдаемость: какие инструменты вызываются, как часто, в каких проектах. Данные нужны для статистики, реальных кейсов в README, и понимания ROI от установки.

Решение — PostToolUse хук на Bash-команды, который логирует вызовы powertools в JSONL + скрипт анализа.

## Новые файлы

```
claude-code-powertools/
├── hooks/
│   └── powertools-logger.sh      # PostToolUse хук-скрипт
├── scripts/
│   ├── setup-tracking.sh         # Одноразовая настройка: копирует хук + обновляет settings.json
│   └── usage-report.sh           # Анализ и отчёт по логу
```

## Компоненты

### 1. `hooks/powertools-logger.sh`

PostToolUse command hook. Получает JSON на stdin от Claude Code.

**Логика:**
1. Читает stdin JSON, извлекает `tool_name`, `tool_input.command`, `cwd`, `session_id`
2. Если `tool_name` != `Bash` → exit 0
3. Извлекает первое слово команды (binary)
4. Проверяет по списку: `tree|yq|shellcheck|fd|rg|scc|difft|jq|fzf|zoxide|eza|lazygit|bat|magick|convert|htop`
5. Если совпадение — пишет строку JSONL в `~/.claude/powertools-usage.jsonl`
6. Exit 0 (неблокирующий)

**Формат записи:**
```jsonl
{"ts":"2026-02-21T14:30:00Z","tool":"shellcheck","cmd":"shellcheck install.sh","project":"claude-code-powertools","session":"abc123"}
```

**Требования:** `jq` (для парсинга stdin JSON). Если jq нет — silent exit 0.

### 2. `scripts/setup-tracking.sh`

Одноразовый скрипт настройки. Отдельно от install.sh (не усложняет основной инсталлятор).

**Шаги:**
1. Проверяет наличие `jq`
2. Создаёт `~/.claude/hooks/` если нет
3. Копирует `powertools-logger.sh` → `~/.claude/hooks/powertools-logger.sh`
4. Добавляет PostToolUse хук в `~/.claude/settings.json` через jq (root level, не под `hooks` ключом — формат user settings)
5. Идемпотентность: проверяет, не добавлен ли уже хук
6. Поддержка `--dry-run` и `--yes`

**Формат хука в settings.json:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/powertools-logger.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. `scripts/usage-report.sh`

Читает `~/.claude/powertools-usage.jsonl` и выводит отчёт.

**Секции отчёта:**
- Общее количество вызовов
- По инструментам (top → bottom)
- По проектам
- По дням (последние 7/30)
- Последние 10 вызовов (для примеров)

**Форматы вывода:**
- `--format text` (default) — человекочитаемый
- `--format markdown` — для вставки в README/docs
- `--format json` — для программного анализа

### 4. Обновления существующих файлов

- **`uninstall.sh`**: добавить удаление `~/.claude/hooks/powertools-logger.sh` и хука из settings.json
- **`CLAUDE.md`**: добавить секцию "Трекинг использования"
- **`README.md`**: добавить секцию "Usage Tracking" с примером отчёта

## Модифицируемые файлы

| Файл | Изменение |
|------|-----------|
| `hooks/powertools-logger.sh` | **Новый** — хук-скрипт |
| `scripts/setup-tracking.sh` | **Новый** — настройка трекинга |
| `scripts/usage-report.sh` | **Новый** — отчёт по использованию |
| `uninstall.sh` | Добавить cleanup хука + settings.json |
| `CLAUDE.md` | Добавить секцию "Трекинг использования" |
| `README.md` | Добавить секцию "Usage Tracking" |

## Verification

```bash
# 1. shellcheck на все новые скрипты
shellcheck hooks/powertools-logger.sh
shellcheck scripts/setup-tracking.sh
shellcheck scripts/usage-report.sh
shellcheck uninstall.sh

# 2. Тест хука вручную (имитация stdin)
echo '{"tool_name":"Bash","tool_input":{"command":"tree -L 2"},"cwd":"/Users/khrupov/projects/test","session_id":"test123"}' | bash hooks/powertools-logger.sh
cat ~/.claude/powertools-usage.jsonl  # должна быть запись

# 3. Тест отчёта
bash scripts/usage-report.sh
bash scripts/usage-report.sh --format markdown

# 4. Dry-run настройки
bash scripts/setup-tracking.sh --dry-run

# 5. Тест идемпотентности setup
bash scripts/setup-tracking.sh --yes
bash scripts/setup-tracking.sh --yes
jq '.hooks.PostToolUse' ~/.claude/settings.json  # не должно быть дублей
```
