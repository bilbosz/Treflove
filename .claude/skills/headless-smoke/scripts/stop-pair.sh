#!/bin/bash
# Stops the pair start-pair.sh <tag> started, by its PIDs, and prints the tails of its logs
[ $# -eq 1 ] || { echo "usage: $0 <tag>" >&2; exit 2; }
dir="/tmp/treflove-smoke/$1"
[ -f "$dir/pids" ] || { echo "$0: no pair $1 running" >&2; exit 1; }
read -r server_pid client_pid < "$dir/pids"
for pid in "$client_pid" "$server_pid"; do
    kill -TERM "$pid" 2>/dev/null
    for _ in $(seq 50); do
        kill -0 "$pid" 2>/dev/null || break
        luajit -e "require('socket').sleep(0.1)"
    done
    kill -KILL "$pid" 2>/dev/null
done
rm -f "$dir/pids"
echo "=== client log (tail) ==="; tail -5 "$dir/client.log"
echo "=== server log (tail) ==="; tail -5 "$dir/server.log"
