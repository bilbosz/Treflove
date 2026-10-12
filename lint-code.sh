#!/bin/bash

#==============================================================================
# Script: lint-code.sh
# Purpose: Run luacheck over the remaining .lua files (config in .luacheckrc;
#          build/ and lib/ are excluded there). Teal (.tlt) is checked by
#          ./build-code.sh.
# Usage: ./lint-code.sh [target_path]
#        target_path defaults to the whole project if not specified
# Examples:
#   ./lint-code.sh                 - lint the entire project
#   ./lint-code.sh app/client.lua  - lint a single file
#   ./lint-code.sh controls/       - lint a directory
#==============================================================================

cd "$(dirname "$0")" || exit 1
exec luacheck "${1:-.}"
