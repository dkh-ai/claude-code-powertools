# claude-code-powertools — Technical Context

## Обзор

Интерактивный инсталлятор CLI-инструментов для macOS, которые усиливают Claude Code и терминал пользователя. Устанавливает до 15 инструментов через Homebrew, конфигурирует `.zshrc` и внедряет справочную таблицу в `~/.claude/CLAUDE.md`.

GitHub: [dkh-ai/claude-code-powertools](https://github.com/dkh-ai/claude-code-powertools)

## Архитектура

```
claude-code-powertools/
├── config/
│   ├── claude-md-toolbox.md      # Шаблон блока для CLAUDE.md (полный пресет)
│   └── zshrc-integrations.sh     # Шаблон блока для .zshrc (полный пресет)
├── hooks/
│   └── powertools-logger.sh      # PostToolUse хук для трекинга использования
├── scripts/
│   ├── setup-tracking.sh         # Настройка трекинга (одноразовая)
│   └── usage-report.sh           # Отчёт по использованию powertools
├── install.sh                    # Основной инсталлятор (~854 строки)
├── uninstall.sh                  # Деинсталлятор
├── README.md                     # Пользовательская документация
└── LICENSE                       # MIT
```

Шаблоны в `config/` — эталонные версии с полным набором инструментов. Инсталлятор генерирует блоки динамически на основе выбранных инструментов.

## Ключевые компоненты

### install.sh

Bash 3.2-совместимый скрипт (без ассоциативных массивов).

**Каталог инструментов** (строки 41–82): 5 параллельных массивов — `TOOL_NAME`, `TOOL_BREW`, `TOOL_CMD`, `TOOL_CAT`, `TOOL_DESC`. Каждый инструмент имеет индекс 0–14.

**Основные функции:**

| Функция | Строки | Назначение |
|---------|--------|------------|
| `parse_args` | 128–150 | Разбор CLI флагов |
| `preflight` | 182–219 | Проверка: root, macOS, архитектура, Homebrew |
| `detect_tty` | 223–229 | Определение pipe vs TTY, auto-`--yes` |
| `apply_preset` | 243–281 | Применение пресета к массиву `TOOL_SELECTED` |
| `interactive_menu` | 317–352 | TUI меню с toggle и пресетами |
| `install_tools` | 368–430 | Batch `brew install`, fallback поштучно |
| `configure_zshrc` | 434–542 | Генерация и вставка блока в `.zshrc` |
| `configure_git` | 546–567 | `git config --global diff.external difft` |
| `configure_claude_md` | 571–717 | Генерация и вставка CLI Toolbox в CLAUDE.md |
| `warn_duplicates` | 759–792 | Детекция дублей fzf/zoxide вне маркеров |
| `main` | 796–853 | Оркестрация всего процесса |

### uninstall.sh

Пять шагов в фиксированном порядке:
1. Удаление блока из `.zshrc` (awk по маркерам)
2. Удаление блока из `CLAUDE.md` (awk по маркерам)
3. Откат `git config diff.external`
4. Опциональный `brew uninstall` (поштучно с подтверждением)
5. Опциональное восстановление из `.powertools-backup`

## Каталог инструментов

| # | Имя | Brew | Команда | Категория |
|---|-----|------|---------|-----------|
| 0 | tree | tree | `tree` | claude |
| 1 | yq | yq | `yq` | claude |
| 2 | shellcheck | shellcheck | `shellcheck` | claude |
| 3 | fd | fd | `fd` | claude |
| 4 | ripgrep | ripgrep | `rg` | claude |
| 5 | scc | scc | `scc` | claude |
| 6 | difftastic | difftastic | `difft` | claude |
| 7 | jq | jq | `jq` | claude |
| 8 | fzf | fzf | `fzf` | user |
| 9 | zoxide | zoxide | `zoxide` | user |
| 10 | eza | eza | `eza` | user |
| 11 | lazygit | lazygit | `lazygit` | user |
| 12 | bat | bat | `bat` | user |
| 13 | imagemagick | imagemagick | `magick` | user |
| 14 | htop | htop | `htop` | user |

Категория `claude` (0–7) — инструменты для Claude Code, `user` (8–14) — для терминала.

## Маркерная система

Идемпотентность обеспечивается маркерами — при повторном запуске старый блок удаляется (awk) и заменяется новым.

| Файл | Начало | Конец |
|------|--------|-------|
| `.zshrc` | `# >>> claude-code-powertools >>>` | `# <<< claude-code-powertools <<<` |
| `CLAUDE.md` | `<!-- claude-code-powertools:begin -->` | `<!-- claude-code-powertools:end -->` |

Перед изменением файлов создаётся бэкап: `файл.powertools-backup`.

## CLI флаги и пресеты

**Флаги:**

| Флаг | Короткий | Действие |
|------|----------|----------|
| `--yes` | `-y` | Пропустить подтверждения |
| `--dry-run` | `-n` | Превью без изменений |
| `--preset NAME` | `-p NAME` | Выбрать пресет |
| `--help` | `-h` | Справка |

**Пресеты:**

| Пресет | Инструменты | Количество |
|--------|-------------|------------|
| `all` / `a` | Все | 15 |
| `claude` / `c` | Индексы 0–7 (по `TOOL_CAT`) | 8 |
| `user` / `u` | Индексы 8–14 (по `TOOL_CAT`) | 7 |
| `minimal` / `m` | tree, shellcheck, fd, jq (индексы 0,2,3,7) | 4 |
| `n` (интерактив) | Снять всё | 0 |

## Расширение функционала

### Добавить новый инструмент

1. Добавить 5 записей в параллельные массивы (`install.sh:41–82`)
2. Добавить строку таблицы в `configure_claude_md` (если `claude`)
3. Добавить блок интеграции в `configure_zshrc` (если `user`)
4. При необходимости добавить правило в секцию Rules
5. Добавить brew-имя в `BREW_PACKAGES` в `uninstall.sh:68`
6. Обновить индексы в `apply_preset` для `minimal` (если нужно)
7. Обновить шаблоны в `config/`

### Удалить инструмент

Убрать из всех перечисленных мест + проверить индексы в `apply_preset` и `configure_zshrc` (жёстко привязаны к числовым индексам).

### Изменить пресет minimal

Правится `apply_preset` (`install.sh:268–273`) — индексы в `TOOL_SELECTED[i]=1`.

## Трекинг использования

Опциональная система наблюдаемости: PostToolUse хук логирует вызовы powertools.

```
hooks/
└── powertools-logger.sh       # PostToolUse хук → ~/.claude/powertools-usage.jsonl
scripts/
├── setup-tracking.sh          # Настройка: копирует хук + обновляет settings.json
└── usage-report.sh            # Анализ логов (text/markdown/json)
```

**Настройка:** `bash scripts/setup-tracking.sh` (одноразово, идемпотентно)

**Как работает:** хук перехватывает Bash-вызовы, извлекает binary, сверяет со списком powertools, пишет JSONL-запись (`ts`, `tool`, `cmd`, `project`, `session`).

**Отчёт:** `bash scripts/usage-report.sh [--format text|markdown|json] [--days N]`

**Удаление:** `bash uninstall.sh` удаляет хук и конфиг из settings.json (шаг 4).

## Известные ограничения

1. **macOS only** — проверка `uname -s` в `preflight`, зависимость от Homebrew
2. **Bash 3.2** — совместимость с macOS-штатным bash (нет ассоциативных массивов)
3. **Нет Linux** — инструменты работают на Linux, но инсталлятор не поддерживает
4. **Индексы жёстко закодированы** — `configure_zshrc` и `configure_claude_md` используют числовые индексы (8 = fzf, 9 = zoxide и т.д.)
5. **Бэкап перезаписывается** — каждый запуск создаёт один `.powertools-backup`, предыдущий теряется
6. **Нет rollback** — восстановление из бэкапа в uninstall заменяет весь файл, а не только блок

## Тестирование

```bash
# Статический анализ
shellcheck install.sh
shellcheck uninstall.sh
shellcheck hooks/powertools-logger.sh
shellcheck scripts/setup-tracking.sh
shellcheck scripts/usage-report.sh

# Dry-run (превью без изменений)
bash install.sh --dry-run
bash install.sh --dry-run --preset claude
bash install.sh --dry-run --preset minimal

# Идемпотентность: повторный запуск не дублирует блоки
bash install.sh --preset claude --yes
bash install.sh --preset claude --yes
grep -c "claude-code-powertools" ~/.zshrc        # ожидается 2 (begin + end)
grep -c "claude-code-powertools" ~/.claude/CLAUDE.md  # ожидается 2

# Трекинг: тест хука
echo '{"tool_name":"Bash","tool_input":{"command":"tree -L 2"},"cwd":"/tmp/test","session_id":"test"}' | bash hooks/powertools-logger.sh

# Трекинг: dry-run настройки
bash scripts/setup-tracking.sh --dry-run
```
