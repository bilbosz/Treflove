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

### VS Code (optional)
- the extensions recommended by the workspace (`.vscode/extensions.json`): the
  language server, the formatter and, behind the launch configurations, the
  Local Lua Debugger (`ismoh-games.second-local-lua-debugger-vscode`)

### Git submodules
- `annotations/love2d` - LÖVE type annotations for the language server
- `annotations/luasocket` - LuaSocket type annotations (LÖVE bundles the library; the clock uses it)
- `annotations/enet` is not a submodule: the lua-enet type annotations, written in this repository (LÖVE bundles the library; the host threads use it)
- `lib/lua-lifetime` - the lua-lifetime runtime (pure Lua; no build step): `git submodule update --init --recursive`

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
