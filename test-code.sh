#!/bin/bash

#==============================================================================
# Script: test-code.sh
# Purpose: Run the automated test suite in tests/
# Usage: ./test-code.sh
#
# Prefers plain LuaJIT (fast, headless); falls back to running the suite
# inside LÖVE (`love . test`), which uses the real love.* implementations.
#==============================================================================

cd "$(dirname "$0")" || exit 1

if command -v luajit > /dev/null 2>&1; then
    exec luajit tests/run.lua
else
    exec love . test
fi
