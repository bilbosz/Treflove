#!/bin/bash

#==============================================================================
# Script: test-code.sh
# Purpose: Build, check that the language server plugin rewrites every
#          .tlt file into valid Lua (editor/luals/check.lua), then run the
#          automated test suite in tests/
# Usage: ./test-code.sh
#
# Prefers plain LuaJIT (fast, headless); falls back to running the suite
# inside LÖVE (`love . test`), which uses the real love.* implementations.
#==============================================================================

cd "$(dirname "$0")" || exit 1

./build-code.sh || exit 1

if command -v luajit > /dev/null 2>&1; then
    find . -name '*.tlt' -not -path './build/*' -not -path './lib/*' | sort | xargs luajit editor/luals/check.lua || exit 1
fi

if command -v luajit > /dev/null 2>&1; then
    exec luajit tests/run.lua
else
    exec love . test
fi
