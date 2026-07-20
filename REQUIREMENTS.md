# Requirements

## Installation

### External Tools
- `lua-format` - `npm install -g lua-format`
- `love` - `sudo apt install love` or download from https://love2d.org/
- `lua-language-server` - `sudo apt install lua-language-server`
- `luacheck` - `sudo apt install lua-check`
- `jq` - `sudo apt install jq`
- `rg` (ripgrep) - `sudo apt install ripgrep`
- `luajit` (optional, for fast headless tests) - `sudo apt install luajit`

### Standard Unix Utilities
- `bash`, `find`, `xargs`, `jobs`, `kill`, `sleep`, `mktemp`, `readlink`

## format-code.sh
- `find`
- `xargs`
- `rg`
- `lua-format`

## run.sh
- `bash`
- `love`
- `jobs`
- `kill`
- `sleep`

## diagnose-code.sh
- `bash`
- `lua-language-server`
- `mktemp`
- `readlink`
- `jq`

## lint-code.sh
- `bash`
- `luacheck`

## test-code.sh
- `bash`
- `luajit` (preferred) or `love` (fallback)
