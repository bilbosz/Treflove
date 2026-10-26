#!/bin/bash

#==============================================================================
# Script: scenario.sh
# Purpose: Run one scenario against a server seeded from a fixture
# Usage: ./scenario.sh <name> [--windowed] [--port <udp port>]
#        [--console <port>] [--server-console <port>] [--fixture <dir>]
#        [--timeout <seconds>]
#==============================================================================

usage() {
    echo "Usage: $0 <name> [--windowed] [--port <udp port>] [--console <port>] [--server-console <port>] [--fixture <dir>] [--timeout <seconds>]" >&2
    exit 2
}

[ $# -ge 1 ] || usage
name="$1"
shift
windowed=0
port=8181
console=9090
server_console=9091
fixture="scenarios/fixtures/basic"
timeout_seconds=120
while [ $# -gt 0 ]; do
    case "$1" in
        --windowed) windowed=1; shift ;;
        --port) [ $# -ge 2 ] || usage; port="$2"; shift 2 ;;
        --console) [ $# -ge 2 ] || usage; console="$2"; shift 2 ;;
        --server-console) [ $# -ge 2 ] || usage; server_console="$2"; shift 2 ;;
        --fixture) [ $# -ge 2 ] || usage; fixture="$2"; shift 2 ;;
        --timeout) [ $# -ge 2 ] || usage; timeout_seconds="$2"; shift 2 ;;
        *) usage ;;
    esac
done

cd "$(dirname "$0")" || exit 1

log_dir="/tmp/treflove-scenario/$name"
mkdir -p "$log_dir"
server_log="$log_dir/server.log"
client_log="$log_dir/client.log"
: > "$server_log"
: > "$client_log"

server_pid=""
stop_server() {
    if [ -n "$server_pid" ]; then
        kill -TERM "$server_pid" 2>/dev/null
        wait "$server_pid" 2>/dev/null
        server_pid=""
    fi
}
trap stop_server EXIT

love . server localhost "$port" --identity treflove-scenario --fixture "$fixture" --console "$server_console" > "$server_log" 2>&1 &
server_pid=$!

client_args=(. client localhost "$port" --identity treflove-scenario --scenario "$name" --console "$console" --server-console "$server_console")
if [ "$windowed" -eq 1 ]; then
    # The app stays open after the scenario: no timeout, the log also on the terminal
    love "${client_args[@]}" 2>&1 | tee "$client_log"
    exit_code=${PIPESTATUS[0]}
else
    SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy timeout "$timeout_seconds" love "${client_args[@]}" --headless > "$client_log" 2>&1
    exit_code=$?
fi

stop_server
if [ "$windowed" -eq 0 ]; then
    cat "$client_log"
fi
exit "$exit_code"
