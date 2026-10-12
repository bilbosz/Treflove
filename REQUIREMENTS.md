# Requirements

## Installation

### External Tools
- `luajit` - `sudo apt install luajit` (runs the build and the headless tests; `lua5.1` works for the build too)
- `love` - `sudo apt install love` or download from https://love2d.org/
- `luacheck` - `sudo apt install lua-check` (lints the few `.lua` files; the Teal sources are checked by the build)
- `git` - the build needs the submodules: `git submodule update --init`

The Teal compiler (`lib/tl`) and the lifetime transpiler and runtime
(`lib/lua-lifetime`) are submodules the build runs from the checkout; the
LÖVE API description (`lib/love-api`) is a submodule only
`tools/gen-love-types.lua` reads. Nothing else is installed.

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
- `xargs`
- `kill`
- `sleep`

## lint-code.sh
- `bash`
- `luacheck`

## test-code.sh
- `bash`
- `luajit` (the build; also preferred for the tests) and `love` (fallback for the tests; CI runs both)

## tools/gen-love-types.lua
- `luajit` (regenerates `types/love.d.tl` from `lib/love-api`)
