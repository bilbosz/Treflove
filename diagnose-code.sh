#!/bin/bash

#==============================================================================
# Script: diagnose-code.sh
# Purpose: Run lua-language-server diagnostics and filter results by target path
# Usage: ./diagnose-code.sh [target_path]
#        target_path defaults to current directory if not specified
#==============================================================================

#------------------------------------------------------------------------------
# Configuration and Setup
#------------------------------------------------------------------------------
target_path="${1:-.}"
script_dir_relative="$(dirname "$0")"
script_dir_absolute="$(readlink -f "$script_dir_relative")"

#------------------------------------------------------------------------------
# Temporary File Management
#------------------------------------------------------------------------------
report_file_path="$(mktemp)"
trap 'rm -f "$report_file_path"' EXIT

#------------------------------------------------------------------------------
# Run Diagnostics
#------------------------------------------------------------------------------
# Suppress lua-language-server output (we only need the JSON report file)
lua-language-server \
  --check . \
  --check_format=json \
  --check_out_path="$report_file_path" \
  --configpath=.luarc.json \
  > /dev/null 2>&1

#------------------------------------------------------------------------------
# Path Resolution
#------------------------------------------------------------------------------
# Convert target to absolute path (resolving symlinks and relative paths)
target_absolute="$(readlink -f "$target_path")"

# Extract relative path by removing the project root prefix
# (e.g., "/home/user/project/src/file.lua" -> "src/file.lua")
# Add 1 to skip the trailing slash separator
target_relative="${target_absolute:${#script_dir_absolute} + 1}"

#------------------------------------------------------------------------------
# Filter and Output Results
#------------------------------------------------------------------------------
# Transform file:// URLs to relative paths and filter for target prefix
jq \
  --arg project_path "file://$script_dir_absolute/" \
  --arg target "$target_relative" \
  '
  with_entries(
    # Step 1: Convert file:// URLs to relative paths
    {
      key: .key[($project_path | length):],
      value: .value
    }
    |
    # Step 2: Filter entries matching the target path prefix
    select(.key | startswith($target))
  )
  ' \
  "$report_file_path"
