<!-- claude-code-powertools:begin -->
**CLI Toolbox** (installed via brew, USE proactively):

| Tool | Use for | Instead of |
|------|---------|------------|
| `tree -L 2 --dirsfirst` | Project structure overview | Multiple ls/Glob calls |
| `scc --no-cocomo` | Codebase size/language stats | `find \| wc -l` |
| `fd -e py` | Find files by name/ext/date | `find . -name` |
| `rg` (system) | Complex Bash pipelines with xargs/sort | Grep tool covers 80% |
| `jq` | JSON parsing/filtering | Python one-liners |
| `yq` | YAML/TOML parsing/filtering | Python one-liners |
| `shellcheck script.sh` | Validate shell scripts after writing | Hope for the best |
| `difft` | Syntax-aware git diff | `git diff --no-ext-diff` for line-based |
| `magick`/`convert` | Batch image resize/convert/watermark | — |
| `htop` | Process monitoring (interactive, for user) | `ps aux` |

**Rules:**
- Run `shellcheck` on every shell script you write or edit
- Use `tree` first when entering unfamiliar project
- Use `scc` when user asks about project scope/size
- Use `yq` for YAML, `jq` for JSON — never write Python for structured data parsing
- `difft` is configured as `git diff.external` globally
<!-- claude-code-powertools:end -->
