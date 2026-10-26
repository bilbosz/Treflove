#!/bin/bash
# Starts a headless server and an offscreen client of this checkout, each with a console, on ports and identities of
# their own, and waits for both consoles: the pair a headless check drives. Stop it with stop-pair.sh <tag>.
# Usage: start-pair.sh <tag> [--port <udp port>] [--server-console <port>] [--client-console <port>]
#        [--fixture <dir>] [--scenario <name>] [--windowed]
# Prints the ports; keeps the PIDs and the logs under /tmp/treflove-smoke/<tag>/.
usage() {
    echo "Usage: $0 <tag> [--port <udp port>] [--server-console <port>] [--client-console <port>] [--fixture <dir>] [--scenario <name>] [--windowed]" >&2
    exit 2
}
[ $# -ge 1 ] || usage
tag="$1"; shift
port=8191; server_console=9191; client_console=9190; fixture="scenarios/fixtures/basic"; scenario=""; windowed=0
while [ $# -gt 0 ]; do
    case "$1" in
        --port) [ $# -ge 2 ] || usage; port="$2"; shift 2 ;;
        --server-console) [ $# -ge 2 ] || usage; server_console="$2"; shift 2 ;;
        --client-console) [ $# -ge 2 ] || usage; client_console="$2"; shift 2 ;;
        --fixture) [ $# -ge 2 ] || usage; fixture="$2"; shift 2 ;;
        --scenario) [ $# -ge 2 ] || usage; scenario="$2"; shift 2 ;;
        --windowed) windowed=1; shift ;;
        *) usage ;;
    esac
done
root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$root" || exit 1
dir="/tmp/treflove-smoke/$tag"
if [ -f "$dir/pids" ]; then
    echo "$0: $tag is running (or was not stopped): $(cat "$dir/pids"); stop-pair.sh $tag first" >&2
    exit 1
fi
console_in_use() { (exec 3<> "/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
for p in "$server_console" "$client_console"; do
    if console_in_use "$p"; then
        echo "$0: the console port $p is in use (the user's own instance, or another pair): pass other ports" >&2
        exit 1
    fi
done
mkdir -p "$dir"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love . server localhost "$port" --identity "smoke-$tag-server" --fixture "$fixture" --console "$server_console" > "$dir/server.log" 2>&1 &
server_pid=$!
client_args=(. client localhost "$port" --identity "smoke-$tag-client" --console "$client_console" --server-console "$server_console")
[ -z "$scenario" ] || client_args+=(--scenario "$scenario")
if [ "$windowed" -eq 1 ]; then
    love "${client_args[@]}" > "$dir/client.log" 2>&1 &
else
    SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy love "${client_args[@]}" --headless > "$dir/client.log" 2>&1 &
fi
client_pid=$!
echo "$server_pid $client_pid" > "$dir/pids"
echo "$port $server_console $client_console" > "$dir/ports"
for p in "$server_console" "$client_console"; do
    for _ in $(seq 100); do
        console_in_use "$p" && break
        luajit -e "require('socket').sleep(0.1)"
    done
    if ! console_in_use "$p"; then
        echo "$0: no console on $p after 10 s; see $dir/server.log and $dir/client.log" >&2
        exit 1
    fi
done
echo "server: udp $port, console $server_console, pid $server_pid; client: console $client_console, pid $client_pid; logs: $dir/"
