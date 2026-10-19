#!/bin/bash

#==============================================================================
# Script: build-code.sh
# Purpose: Build every .tlt module into build/ (transpile with lua-lifetime's
#          Teal front end, type-check and generate Lua with tl). The build is
#          also the type checker: it exits non-zero on any error.
# Usage: ./build-code.sh [FILE.tlt...]
#        with files, only those are checked and generated (into the existing
#        build/); without, the whole tree is rebuilt from scratch
# Requires: luajit (or lua5.1) and the submodules (git submodule update --init)
#==============================================================================

cd "$(dirname "$0")" || exit 1

if command -v luajit > /dev/null 2>&1; then
    exec luajit tools/build.lua "$@"
else
    exec lua5.1 tools/build.lua "$@"
fi
