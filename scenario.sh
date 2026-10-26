#!/bin/bash

#==============================================================================
# Script: scenario.sh
# Purpose: Run one scenario against a server seeded from a fixture, with one
#          client more for every peer the scenario names
# Usage: ./scenario.sh <name> [--windowed] [--port <udp port>]
#        [--console <port>] [--server-console <port>] [--fixture <dir>]
#        [--timeout <seconds>] [--identity <name>]
#==============================================================================

usage() {
    echo "Usage: $0 <name> [--windowed] [--port <udp port>] [--console <port>] [--server-console <port>] [--fixture <dir>] [--timeout <seconds>] [--identity <name>]" >&2
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
identity=treflove-scenario
while [ $# -gt 0 ]; do
    case "$1" in
        --windowed) windowed=1; shift ;;
        --port) [ $# -ge 2 ] || usage; port="$2"; shift 2 ;;
        --console) [ $# -ge 2 ] || usage; console="$2"; shift 2 ;;
        --server-console) [ $# -ge 2 ] || usage; server_console="$2"; shift 2 ;;
        --fixture) [ $# -ge 2 ] || usage; fixture="$2"; shift 2 ;;
        --timeout) [ $# -ge 2 ] || usage; timeout_seconds="$2"; shift 2 ;;
        --identity) [ $# -ge 2 ] || usage; identity="$2"; shift 2 ;;
        *) usage ;;
    esac
done

cd "$(dirname "$0")" || exit 1

scenario_peers() {
    luajit - "scenarios/$1.lua" <<'LUA'
package.path = "./?.lua;lib/lua-lifetime/?.lua;lib/lua-lifetime/?/init.lua;" .. package.path
require("app.globals")
local scenario = dofile(arg[1])
if type(scenario) == "table" then
    for _, peer in ipairs(scenario.peers or {}) do
        print(peer)
    end
end
LUA
}

# The lead connects to a peer's console at its first call, so the console must be open before the lead starts
wait_for_console() {
    local console_port="$1" pid="$2"
    for _ in $(seq 100); do
        if (exec 3<> "/dev/tcp/127.0.0.1/$console_port") 2>/dev/null; then
            return 0
        fi
        kill -0 "$pid" 2>/dev/null || return 1
        sleep 0.1
    done
    return 1
}

if ! peers=$(scenario_peers "$name"); then
    echo "$0: cannot read the peers of scenarios/$name.lua" >&2
    exit 2
fi
peer_names=()
[ -z "$peers" ] || mapfile -t peer_names <<< "$peers"

# A console port in use belongs to another instance (run.sh's client or server): the scenario's calls would reach it
console_in_use() {
    (exec 3<> "/dev/tcp/127.0.0.1/$1") 2>/dev/null
}
refuse_console_in_use() {
    if console_in_use "$1"; then
        echo "$0: the console port $1 is in use by another instance; pass --console and --server-console of your own" >&2
        exit 2
    fi
}
refuse_console_in_use "$console"
refuse_console_in_use "$server_console"
for i in "${!peer_names[@]}"; do
    refuse_console_in_use $((console + 10 + i))
done

# Runs with an identity of their own (several at once) keep their save directories and logs apart
if [ "$identity" = treflove-scenario ]; then
    log_dir="/tmp/treflove-scenario/$name"
else
    log_dir="/tmp/treflove-scenario/$identity/$name"
fi
mkdir -p "$log_dir"
server_log="$log_dir/server.log"
client_log="$log_dir/client.log"
: > "$server_log"
: > "$client_log"

server_pid=""
peer_pids=()
stop_all() {
    for pid in "${peer_pids[@]}" $server_pid; do
        kill -TERM "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    done
    peer_pids=()
    server_pid=""
}
trap stop_all EXIT

love . server localhost "$port" --identity "$identity" --fixture "$fixture" --console "$server_console" > "$server_log" 2>&1 &
server_pid=$!

peer_consoles=()
for i in "${!peer_names[@]}"; do
    peer="${peer_names[$i]}"
    peer_console=$((console + 10 + i))
    peer_log="$log_dir/$peer.log"
    peer_args=(. client localhost "$port" --identity "$identity-$peer" --console "$peer_console" --server-console "$server_console")
    if [ "$windowed" -eq 1 ]; then
        love "${peer_args[@]}" > "$peer_log" 2>&1 &
    else
        SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy timeout "$timeout_seconds" love "${peer_args[@]}" --headless > "$peer_log" 2>&1 &
    fi
    peer_pids+=($!)
    peer_consoles+=("$peer_console")
done
peer_option=()
for i in "${!peer_names[@]}"; do
    if ! wait_for_console "${peer_consoles[$i]}" "${peer_pids[$i]}"; then
        echo "$0: the peer ${peer_names[$i]} opened no console on ${peer_consoles[$i]}, see $log_dir/${peer_names[$i]}.log" >&2
        exit 1
    fi
    peer_option+=("${peer_names[$i]}:${peer_consoles[$i]}")
done

client_args=(. client localhost "$port" --identity "$identity" --scenario "$name" --console "$console" --server-console "$server_console")
if [ ${#peer_option[@]} -gt 0 ]; then
    client_args+=(--peers "$(IFS=,; echo "${peer_option[*]}")")
fi
if [ "$windowed" -eq 1 ]; then
    # The app stays open after the scenario: no timeout, the log also on the terminal
    love "${client_args[@]}" 2>&1 | tee "$client_log"
    exit_code=${PIPESTATUS[0]}
else
    SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy timeout "$timeout_seconds" love "${client_args[@]}" --headless > "$client_log" 2>&1
    exit_code=$?
fi

stop_all
if [ "$windowed" -eq 0 ]; then
    cat "$client_log"
fi
exit "$exit_code"
