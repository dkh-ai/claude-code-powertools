# claude-code-powertools

CLI tools that make Claude Code smarter and your terminal more powerful. One command installs and configures everything.

```bash
curl -sL https://raw.githubusercontent.com/dkh-ai/claude-code-powertools/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/dkh-ai/claude-code-powertools.git
cd claude-code-powertools
bash install.sh
```

## What This Does

Claude Code has a Bash tool that lets it run terminal commands. By default, it uses basic Unix utilities — `find`, `grep`, `cat` — that get the job done but aren't optimal. Modern CLI tools are faster, produce better output, and give Claude Code capabilities it doesn't have out of the box (like structural diffs, YAML parsing, or codebase statistics).

This installer does three things: (1) installs up to 15 CLI tools via Homebrew, (2) configures your shell with aliases and integrations, and (3) teaches Claude Code about the new tools by injecting a reference table into your `CLAUDE.md`.

The tools are split into two categories: **For Claude Code** (8 tools Claude uses directly) and **For You** (7 tools that enhance your terminal experience). You can install both, one category, or pick individual tools.

## Tool Catalog

### For Claude Code

These tools are used by Claude Code through its Bash tool. The installer adds a reference table to your `CLAUDE.md` so Claude knows when and how to use each one.

---

#### tree

> Project structure overview

When Claude Code enters an unfamiliar project, it needs to understand the directory layout. `tree` gives a clean, hierarchical view of the project in a single command. Without it, Claude has to make multiple `ls` or `Glob` calls to build a mental model of the structure.

```bash
tree -L 2 --dirsfirst          # Two levels deep, dirs first
tree -L 3 -I node_modules      # Three levels, ignore node_modules
tree -P "*.ts" --prune          # Only TypeScript files
```

**Replaces:** Multiple `ls`/`Glob` calls

---

#### yq

> YAML/TOML/XML parsing and filtering

YAML is everywhere — Kubernetes manifests, CI/CD configs, Docker Compose files. `yq` lets Claude Code read, query, and modify structured data without writing Python scripts. It uses the same syntax as `jq` but works across YAML, TOML, and XML.

```bash
yq '.services.web.ports' docker-compose.yml    # Extract ports
yq -i '.version = "2.0"' config.yaml           # Edit in place
yq -o json config.yaml                         # Convert YAML to JSON
```

**Replaces:** Python one-liners for YAML parsing

---

#### shellcheck

> Shell script static analysis

When Claude Code writes or edits shell scripts, `shellcheck` catches bugs before they run — unused variables, unquoted expansions, POSIX compatibility issues. The installer adds a rule to `CLAUDE.md` telling Claude to run `shellcheck` on every script it writes.

```bash
shellcheck script.sh                # Analyze a script
shellcheck -e SC2086 script.sh      # Exclude specific warnings
shellcheck -f diff script.sh        # Output as diff (auto-fixable)
```

**Replaces:** Manual script review / hope for the best

---

#### fd

> Modern file finder (replaces find)

`fd` is a fast, user-friendly alternative to `find`. It respects `.gitignore`, uses regex by default, and has sensible defaults. Claude Code uses it when it needs to find files by name, extension, or modification date.

```bash
fd -e py                     # Find all Python files
fd -e ts --changed-within 1d # TypeScript files changed today
fd "test" --type f           # Files containing "test" in name
```

**Replaces:** `find . -name "*.py"`

---

#### ripgrep

> Fast code search for Bash pipelines

Claude Code has a built-in Grep tool, but `rg` (ripgrep) is useful when Claude needs to chain searches with other commands — piping through `sort`, `uniq`, `xargs`, or `jq`. It's the fastest grep tool available and respects `.gitignore`.

```bash
rg "TODO|FIXME" --count          # Count TODOs per file
rg -l "import React" | xargs wc -l  # Line count of React files
rg "api/" --json | jq '.data'    # Structured output
```

**Replaces:** System `grep` in complex Bash pipelines (Claude's Grep tool covers 80% of use cases)

---

#### scc

> Codebase statistics by language

When you ask "how big is this project?" or "what languages does it use?", `scc` answers instantly. It counts lines of code, comments, and blanks per language, with complexity estimates.

```bash
scc --no-cocomo              # Stats without cost estimates
scc --by-file --sort lines   # Per-file breakdown
scc src/                     # Stats for a specific directory
```

**Replaces:** `find | wc -l`, `cloc`

---

#### difftastic

> AST-aware structural git diff

Normal `git diff` shows line-by-line text changes. `difft` (difftastic) understands your programming language's syntax tree and shows structural changes — moved functions, renamed variables, reformatted code. The installer configures it as git's default diff tool.

```bash
difft file-a.py file-b.py    # Compare two files
git diff                     # Uses difft automatically after install
git diff --no-ext-diff       # Bypass difft, use normal diff
```

**Replaces:** Line-based `git diff` (use `--no-ext-diff` when you need the original)

---

#### jq

> JSON parsing and filtering

JSON is the lingua franca of APIs and config files. `jq` lets Claude Code extract, transform, and query JSON data without Python. Essential for working with API responses, package.json, and any structured data.

```bash
jq '.dependencies' package.json          # Extract dependencies
jq '.[] | select(.status == "active")'   # Filter arrays
curl -s api.example.com | jq '.data'     # Parse API response
```

**Replaces:** Python one-liners for JSON parsing

---

### For You

These tools enhance your daily terminal experience with better defaults, smarter navigation, and visual improvements. The installer adds shell integrations to your `.zshrc`.

---

#### fzf

> Fuzzy finder (Ctrl+R, Ctrl+T, Alt+C)

`fzf` transforms three keyboard shortcuts into superpowers. **Ctrl+R** gives you fuzzy search through command history (no more pressing up arrow 50 times). **Ctrl+T** lets you find and insert file paths interactively. **Alt+C** jumps into any subdirectory. Once you try it, you can't go back.

```bash
# After installation, just use the keyboard shortcuts:
# Ctrl+R  →  fuzzy search command history
# Ctrl+T  →  fuzzy find files
# Alt+C   →  fuzzy cd into directories
vim $(fzf)     # Open a file picked interactively
```

**Replaces:** Up-arrow history, `ls` + `cd` dance

---

#### zoxide

> Smart cd that learns your directories

`zoxide` replaces `cd` with a smarter version that remembers which directories you visit most. Type `z proj` and it jumps to `~/projects` (or wherever you go most often that matches "proj"). No more typing full paths.

```bash
z proj           # Jump to most-visited directory matching "proj"
z doc            # Jump to your documents/docs directory
zi               # Interactive picker with fuzzy search
```

**Replaces:** `cd ~/long/path/to/directory`

---

#### eza

> Modern ls with git and icons

`eza` replaces `ls` with colorful output, git status indicators, and file icons. The installer sets up four aliases: `ls` (basic), `ll` (long + git), `lt` (tree view), and `la` (show hidden).

```bash
ls               # Colorful file listing (eza)
ll               # Long format with git status + icons
lt               # Tree view (2 levels, respects .gitignore)
la               # Show hidden files
```

**Replaces:** Plain `ls` output

---

#### lazygit

> Full git TUI

A terminal UI for git that makes complex operations visual. Stage individual hunks, interactive rebase, cherry-pick, manage stashes — all without memorizing git flags. Aliased to `lg`.

```bash
lg               # Launch lazygit in current repo
```

**Replaces:** Complex `git` command sequences

---

#### bat

> cat with syntax highlighting

`bat` is `cat` with syntax highlighting, line numbers, and git integration. The installer aliases `cat` to `bat`, so every time you view a file you get beautiful, highlighted output.

```bash
cat file.py      # Syntax-highlighted output (bat)
bat -A file.txt  # Show invisible characters
bat -l json      # Force JSON highlighting
```

**Replaces:** Plain `cat` output

---

#### imagemagick

> Batch image processing

`imagemagick` gives Claude Code (and you) the ability to resize, convert, crop, and manipulate images from the command line. Useful for batch processing screenshots, generating thumbnails, or converting between formats.

```bash
magick input.png -resize 50% output.png          # Resize
magick input.jpg -quality 80 output.webp          # Convert format
magick mogrify -resize 800x600 screenshots/*.png  # Batch resize
```

**Replaces:** Opening an image editor for simple operations

---

#### htop

> Interactive process monitor

`htop` is a visual, interactive process manager. Use it when you need to see what's consuming CPU/memory, kill stuck processes, or monitor system load.

```bash
htop             # Interactive process viewer
```

**Replaces:** `ps aux | grep`, Activity Monitor

---

## Presets

| Preset | Flag | Tools | Count |
|--------|------|-------|-------|
| All | `--preset all` | Everything | 15 |
| Claude Code | `--preset claude` | tree, yq, shellcheck, fd, ripgrep, scc, difftastic, jq | 8 |
| User | `--preset user` | fzf, zoxide, eza, lazygit, bat, imagemagick, htop | 7 |
| Minimal | `--preset minimal` | tree, shellcheck, fd, jq | 4 |

In interactive mode, you can also type preset letters: `a` (all), `c` (claude), `u` (user), `m` (minimal), `n` (none).

## What Gets Configured

### ~/.zshrc

A managed block between marker comments is appended to your `.zshrc`:

```bash
# >>> claude-code-powertools >>>
# ... shell integrations for fzf, zoxide, bat, eza, lazygit ...
# <<< claude-code-powertools <<<
```

All integrations are guarded with `command -v` checks — they only activate if the tool is installed. Re-running the installer replaces the block cleanly.

### git config

If you install difftastic, the installer sets `git config --global diff.external difft`, making `difft` the default diff viewer. Use `git diff --no-ext-diff` when you need the original line-based diff.

### ~/.claude/CLAUDE.md

A managed block between HTML comment markers is appended:

```markdown
<!-- claude-code-powertools:begin -->
**CLI Toolbox** (installed via brew, USE proactively):
| Tool | Use for | Instead of |
...
**Rules:**
...
<!-- claude-code-powertools:end -->
```

This teaches Claude Code when and how to use each tool. Only tools you actually installed are included in the table.

## CLI Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--yes` | `-y` | Skip all confirmations (auto-accept) |
| `--dry-run` | `-n` | Preview changes without modifying anything |
| `--preset NAME` | `-p NAME` | Pre-select tools: `all`, `claude`, `user`, `minimal` |
| `--help` | `-h` | Show help |

### Examples

```bash
# Interactive (default) — shows menu, lets you toggle tools
bash install.sh

# Install Claude Code tools only, no questions asked
bash install.sh --preset claude --yes

# Preview what would happen
bash install.sh --dry-run

# Install everything non-interactively (good for CI/automation)
bash install.sh --preset all --yes

# Piped install (auto-detects no TTY, uses --yes)
curl -sL .../install.sh | bash
```

## Uninstall

```bash
bash uninstall.sh
```

Or remotely:

```bash
curl -sL https://raw.githubusercontent.com/dkh-ai/claude-code-powertools/main/uninstall.sh | bash
```

The uninstaller:
1. Removes the managed block from `.zshrc`
2. Removes the managed block from `CLAUDE.md`
3. Reverts `git config diff.external` if set to `difft`
4. Offers to `brew uninstall` each tool (with per-tool confirmation)
5. Offers to restore backup files created during installation

## FAQ

**Does this work on Linux?**
Not yet. The installer is macOS-only because it relies on Homebrew. All the tools themselves work on Linux — you'd just install them through your package manager.

**Will this break my existing .zshrc / CLAUDE.md?**
No. The installer creates backup files (`.powertools-backup`) before making changes. All modifications are contained within marker comments, so they can be cleanly removed. The installer also warns if it detects duplicate integrations.

**What if I already have some of these tools?**
The installer detects already-installed tools and skips them. They'll show as "(installed)" in the interactive menu and "Already present" in the summary.

**Can I run it again after adding/removing tools?**
Yes, the installer is idempotent. On re-run it replaces the previous marker blocks with fresh ones based on your current selection.

**Does Claude Code automatically use these tools?**
Yes, once the CLI Toolbox section is in your `CLAUDE.md`. Claude Code reads this file and follows the rules — for example, running `shellcheck` after writing scripts, or using `tree` when exploring a new project.

**What's the "minimal" preset?**
Four essential tools: `tree` (project overview), `shellcheck` (script validation), `fd` (file finding), and `jq` (JSON parsing). These give Claude Code the biggest capability boost with the smallest footprint.

## License

MIT
