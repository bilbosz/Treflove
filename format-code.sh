#!/bin/bash

#==============================================================================
# Script: format-code.sh
# Purpose: Format the Lua files in place with lua-format (config in
#          .lua-format): main.lua, conf.lua, tests/run.lua, tools/ and
#          .vscode/launch.lua, and nothing else: build/ is generated,
#          lib/ holds the submodules and server/save.lua is data the
#          server writes. Nothing formats the Teal sources (.tlt, .d.tl):
#          lua-format reads Lua only.
# Usage: ./format-code.sh [FILE.lua...]
#        with files, only those are formatted
# Requires: lua-format (REQUIREMENTS.md)
#==============================================================================

cd "$(dirname "$0")" || exit 1

if [ $# -gt 0 ]; then
    exec lua-format -i "$@"
fi

exec lua-format -i main.lua conf.lua tests/run.lua tools/*.lua .vscode/launch.lua
