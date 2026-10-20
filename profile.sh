#!/bin/bash

#==============================================================================
# Script: profile.sh
# Purpose: Run the server and the client, one of them under the Tracy profiler
# Usage: ./profile.sh [client|server] [path/to/libTracyClient.so]
#
# The side named first (default: client) runs with TREFLOVE_TRACY set to the
# Tracy client library (default: $TREFLOVE_TRACY, else the one
# build-tracy.sh built); the other side runs plain. Connect the Tracy GUI
# of the same version to localhost to capture.
#==============================================================================

cd "$(dirname "$0")" || exit 1

function on_exit() {
    jobs -p | xargs -n1 kill -9
}

trap 'on_exit' EXIT

side=${1:-client}
library=${2:-${TREFLOVE_TRACY:-}}
if [ -z "$library" ]; then
    library=$(find lib/tracy/build -maxdepth 2 \( -name 'libTracyClient.so' -o -name 'TracyClient.dll' -o -name 'libTracyClient.dylib' \) 2> /dev/null | head -n 1)
fi
if [ -z "$library" ] || [ ! -f "$library" ]; then
    echo "No Tracy client library: run ./build-tracy.sh or pass its path" >&2
    exit 1
fi
library=$(readlink -f "$library")

case "$side" in
    client)
        love . server localhost 8080 &
        sleep 0
        TREFLOVE_TRACY="$library" love . client localhost 8080
        ;;
    server)
        TREFLOVE_TRACY="$library" love . server localhost 8080 &
        sleep 0
        love . client localhost 8080
        ;;
    *)
        echo "Usage: $0 [client|server] [path/to/libTracyClient.so]" >&2
        exit 1
        ;;
esac
