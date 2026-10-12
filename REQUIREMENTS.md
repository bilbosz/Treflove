# Requirements

## Installation

### External Tools
- `luajit` - `sudo apt install luajit` (runs the build and the headless tests; `lua5.1` works for the build too)
- `love` - `sudo apt install love` or download from https://love2d.org/
- `luacheck` - `sudo apt install lua-check`
- `git` - the build needs the submodules: `git submodule update --init`

The Teal compiler (`lib/tl`), the lifetime transpiler and runtime
(`lib/lua-lifetime`) and the LÖVE API description (`lib/love-api`) are
submodules; nothing else is installed.

### Standard Unix Utilities
- `bash`, `find`, `ls`, `mkdir`, `rm`, `xargs`, `jobs`, `kill`, `sleep`

## build-code.sh
- `bash`
- `luajit` (or `lua5.1`)
- `find`, `ls`, `mkdir`, `rm`

## run.sh
- `bash`
- `luajit` (the build)
- `love`
- `jobs`
- `kill`
- `sleep`

## lint-code.sh
- `bash`
- `luacheck`

## test-code.sh
- `bash`
- `luajit` (the build; also preferred for the tests) and `love` (fallback for the tests)

## tools/gen-love-types.lua
- `luajit` (regenerates `types/love.d.tl` from `lib/love-api`)
