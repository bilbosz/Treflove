#!/bin/bash
# Prints the `auth` of a fixture account (scenarios/fixtures/<name>/accounts.lua): usage: player-auth.sh <login> <password>
[ $# -eq 2 ] || { echo "usage: $0 <login> <password>" >&2; exit 2; }
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy love "$(cd "$(dirname "$0")" && pwd)/player-auth" "$1" "$2"
