#!/bin/bash

#==============================================================================
# Script: build-tracy.sh
# Purpose: Build the Tracy client as a shared library for the profiler
# Usage: ./build-tracy.sh
#
# Clones Tracy at the pinned version into lib/tracy (ignored by git) and
# builds lib/tracy/build/libTracyClient.so (TracyClient.dll on Windows,
# libTracyClient.dylib on macOS). TRACY_ON_DEMAND stays off: the profiler's
# FFI binding declares the zone context of a client built without it.
# The Tracy GUI must be the same version: see docs/profiling.md.
#==============================================================================

set -e
cd "$(dirname "$0")" || exit 1

TRACY_VERSION=v0.14.1
TRACY_DIR=lib/tracy
BUILD_DIR="$TRACY_DIR/build"

if [ ! -d "$TRACY_DIR/.git" ]; then
    git clone --depth 1 --branch "$TRACY_VERSION" https://github.com/wolfpld/tracy.git "$TRACY_DIR"
fi

cmake -S "$TRACY_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DTRACY_STATIC=OFF \
    -DTRACY_ENABLE=ON \
    -DTRACY_ON_DEMAND=OFF
cmake --build "$BUILD_DIR" --config Release --parallel

library=$(find "$BUILD_DIR" -maxdepth 2 \( -name 'libTracyClient.so' -o -name 'TracyClient.dll' -o -name 'libTracyClient.dylib' \) | head -n 1)
if [ -z "$library" ]; then
    echo "The Tracy client library was not found under $BUILD_DIR" >&2
    exit 1
fi
echo
echo "Tracy client: $(readlink -f "$library")"
echo "Profile the client with: ./profile.sh"
echo "Or by hand: TREFLOVE_TRACY=$(readlink -f "$library") love . client localhost 8080"
